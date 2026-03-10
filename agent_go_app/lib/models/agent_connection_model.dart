class AgentConnectionModel {
  final String id;
  final String managerId;
  final String ownerId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Joins
  final String? managerName;
  final String? ownerName;
  final String? ownerAgentCode;

  AgentConnectionModel({
    required this.id,
    required this.managerId,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.managerName,
    this.ownerName,
    this.ownerAgentCode,
  });

  factory AgentConnectionModel.fromJson(Map<String, dynamic> json) {
    return AgentConnectionModel(
      id: json['id'] as String,
      managerId: json['manager_id'] as String,
      ownerId: json['owner_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      managerName: json['manager']?['name'] as String?,
      ownerName: json['owner']?['name'] as String?,
      ownerAgentCode: json['owner']?['agent_code'] as String?,
    );
  }
}
