const fs = require('fs');
const path = require('path');

const csvPath = '/Users/cibirajanv/AgentGo/excel-policy-list.csv';
const userId = '7f2bf5fb-ee9f-438f-8e42-701f4b5b9138';

function parseCSVLine(line) {
    const result = [];
    let current = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
        const char = line[i];
        if (char === '"') {
            inQuotes = !inQuotes;
        } else if (char === ',' && !inQuotes) {
            result.push(current.trim());
            current = '';
        } else {
            current += char;
        }
    }
    result.push(current.trim());
    return result;
}

function parseDate(dateStr) {
    if (!dateStr || dateStr === 'N/A') return null;
    // Handle DD-MM-YYYY or DD/MM/YYYY
    const parts = dateStr.split(/[-/]/);
    if (parts.length !== 3) return null;
    const day = parts[0].padStart(2, '0');
    const month = parts[1].padStart(2, '0');
    let year = parts[2];
    if (year.length === 2) year = '20' + year; // Guessing 20th/21st century
    return `${year}-${month}-${day}`;
}

const content = fs.readFileSync(csvPath, 'utf-8');
const lines = content.split('\n');

// Headers are at line 5 (index 4)
const headers = parseCSVLine(lines[4]);
console.log('Headers:', headers);

const clients = [];
for (let i = 5; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;
    const row = parseCSVLine(line);
    if (row.length < 10) continue;

    const fullName = row[2];
    const dob = parseDate(row[3]);
    const mobile = row[4];
    const email = row[5];
    const address = row[6];
    const policyNumber = row[7];
    const commencementDate = parseDate(row[9]);
    const plan = row[10];
    const term = parseInt(row[11]) || 0;
    const sumAssured = row[13];
    const mode = row[14];
    const premium = row[16];
    const nominee = row[17];

    let policyEndDate = null;
    if (commencementDate && term > 0) {
        const d = new Date(commencementDate);
        d.setFullYear(d.getFullYear() + term);
        policyEndDate = d.toISOString().split('T')[0];
    }

    clients.push({
        full_name: fullName,
        date_of_birth: dob,
        mobile_number: mobile,
        email: email,
        Address: address,
        Policy_Number: policyNumber,
        Plan: plan,
        "Date of commision": commencementDate,
        policy_start_date: commencementDate,
        policy_end_date: policyEndDate,
        Sum: sumAssured,
        Mode: mode,
        Premium: premium,
        nominee: nominee,
        user_id: userId,
        "notification?": true,
        mobile_number_cc: '+91'
    });
}

console.log(`Total records parsed: ${clients.length}`);

// Generate SQL batches
const BATCH_SIZE = 50;
for (let i = 0; i < clients.length; i += BATCH_SIZE) {
    const batch = clients.slice(i, i + BATCH_SIZE);
    const values = batch.map(c => {
        const escape = (val) => {
            if (val === null || val === undefined) return 'NULL';
            if (typeof val === 'boolean') return val;
            return `'${String(val).replace(/'/g, "''")}'`;
        };
        return `(
      ${escape(c.full_name)},
      ${escape(c.date_of_birth)},
      ${escape(c.mobile_number)},
      ${escape(c.email)},
      ${escape(c.Address)},
      ${escape(c.Policy_Number)},
      ${escape(c.Plan)},
      ${escape(c["Date of commision"])},
      ${escape(c.policy_start_date)},
      ${escape(c.policy_end_date)},
      ${escape(c.Sum)},
      ${escape(c.Mode)},
      ${escape(c.Premium)},
      ${escape(c.nominee)},
      ${escape(c.user_id)},
      ${c["notification?"]},
      ${escape(c.mobile_number_cc)}
    )`;
    }).join(',');

    const sql = `
    INSERT INTO public.client (
      full_name, date_of_birth, mobile_number, email, "Address", "Policy_Number", "Plan", 
      "Date of commision", policy_start_date, policy_end_date, "Sum", "Mode", "Premium", 
      nominee, user_id, "notification?", mobile_number_cc
    ) VALUES ${values}
    ON CONFLICT ("Policy_Number") DO NOTHING;
  `;

    fs.writeFileSync(`/tmp/batch_${i / BATCH_SIZE}.sql`, sql);
}

console.log(`Batches generated: ${Math.ceil(clients.length / BATCH_SIZE)}`);
