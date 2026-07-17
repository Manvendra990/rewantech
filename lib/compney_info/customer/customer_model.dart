import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SocialAccount {
  final String platform;
  final String id;
  final String password;

  SocialAccount({
    required this.platform,
    required this.id,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {'platform': platform, 'id': id, 'password': password};
  }

  factory SocialAccount.fromMap(Map<String, dynamic> map) {
    return SocialAccount(
      platform: map['platform'] ?? '',
      id: map['id'] ?? '',
      password: map['password'] ?? '',
    );
  }
}

enum PaymentStatus { pending, completed, overdue }

extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.overdue:
        return 'Overdue';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.completed:
        return Colors.green;
      case PaymentStatus.overdue:
        return Colors.red;
    }
  }

  static PaymentStatus fromLabel(String? label) {
    switch (label) {
      case 'Completed':
        return PaymentStatus.completed;
      case 'Overdue':
        return PaymentStatus.overdue;
      case 'Pending':
      default:
        return PaymentStatus.pending;
    }
  }
}

class ServiceProvided {
  final DateTime startDate;
  final String serviceName;
  final double monthlyCharges;
  final DateTime paymentDate;
  final PaymentStatus paymentStatus;
  final String monthlyTasks;
  final DateTime? paymentReceivedDate;
  final DateTime? nextPaymentDate;

  ServiceProvided({
    required this.startDate,
    required this.serviceName,
    required this.monthlyCharges,
    required this.paymentDate,
    required this.paymentStatus,
    required this.monthlyTasks,
    this.paymentReceivedDate,
    this.nextPaymentDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'serviceName': serviceName,
      'monthlyCharges': monthlyCharges,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'paymentStatus': paymentStatus.label,
      'monthlyTasks': monthlyTasks,
      'paymentReceivedDate': paymentReceivedDate != null
          ? Timestamp.fromDate(paymentReceivedDate!)
          : null,
      'nextPaymentDate': nextPaymentDate != null
          ? Timestamp.fromDate(nextPaymentDate!)
          : null,
    };
  }

  factory ServiceProvided.fromMap(Map<String, dynamic> map) {
    return ServiceProvided(
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      serviceName: map['serviceName'] ?? '',
      monthlyCharges: (map['monthlyCharges'] is num)
          ? (map['monthlyCharges'] as num).toDouble()
          : double.tryParse('${map['monthlyCharges']}') ?? 0,
      paymentDate:
          (map['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentStatus: PaymentStatusX.fromLabel(map['paymentStatus']),
      monthlyTasks: map['monthlyTasks'] ?? '',
      paymentReceivedDate: (map['paymentReceivedDate'] as Timestamp?)?.toDate(),
      nextPaymentDate: (map['nextPaymentDate'] as Timestamp?)?.toDate(),
    );
  }
}

class DealDetails {
  final String? leadId;
  final String projectName;
  final String description;
  final String serviceName;
  final String agentName;
  final String paymentType; 
  final double totalAmount;
  final double? monthlyAmount;
  final double amountReceived;
  final double pendingAmount;
  final String paymentMethod;
  final double? incentivePercent;
  final double? incentiveAmount;
  final DateTime? dealClosedDate;
  final DateTime? nextPaymentDate;

  DealDetails({
    this.leadId,
    required this.projectName,
    required this.description,
    required this.serviceName,
    required this.agentName,
    required this.paymentType,
    required this.totalAmount,
    this.monthlyAmount,
    required this.amountReceived,
    required this.pendingAmount,
    required this.paymentMethod,
    this.incentivePercent,
    this.incentiveAmount,
    this.dealClosedDate,
    this.nextPaymentDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'leadId': leadId,
      'projectName': projectName,
      'description': description,
      'serviceName': serviceName,
      'agentName': agentName,
      'paymentType': paymentType,
      'totalAmount': totalAmount,
      'monthlyAmount': monthlyAmount,
      'amountReceived': amountReceived,
      'pendingAmount': pendingAmount,
      'paymentMethod': paymentMethod,
      'incentivePercent': incentivePercent,
      'incentiveAmount': incentiveAmount,
      'dealClosedDate': dealClosedDate != null
          ? Timestamp.fromDate(dealClosedDate!)
          : null,
      'nextPaymentDate': nextPaymentDate != null
          ? Timestamp.fromDate(nextPaymentDate!)
          : null,
    };
  }

  factory DealDetails.fromMap(Map<String, dynamic> map) {
    return DealDetails(
      leadId: map['leadId'],
      projectName: map['projectName'] ?? '',
      description: map['description'] ?? '',
      serviceName: map['serviceName'] ?? '',
      agentName: map['agentName'] ?? '',
      paymentType: map['paymentType'] ?? 'One-time',
      totalAmount: (map['totalAmount'] is num)
          ? (map['totalAmount'] as num).toDouble()
          : double.tryParse('${map['totalAmount']}') ?? 0,
      monthlyAmount: map['monthlyAmount'] is num
          ? (map['monthlyAmount'] as num).toDouble()
          : null,
      amountReceived: (map['amountReceived'] is num)
          ? (map['amountReceived'] as num).toDouble()
          : double.tryParse('${map['amountReceived']}') ?? 0,
      pendingAmount: (map['pendingAmount'] is num)
          ? (map['pendingAmount'] as num).toDouble()
          : double.tryParse('${map['pendingAmount']}') ?? 0,
      paymentMethod: map['paymentMethod'] ?? 'Bank Transfer',
      incentivePercent: map['incentivePercent'] is num
          ? (map['incentivePercent'] as num).toDouble()
          : null,
      incentiveAmount: map['incentiveAmount'] is num
          ? (map['incentiveAmount'] as num).toDouble()
          : null,
      dealClosedDate: (map['dealClosedDate'] as Timestamp?)?.toDate(),
      nextPaymentDate: (map['nextPaymentDate'] as Timestamp?)?.toDate(),
    );
  }
}

class Customer {
  final String docId;
  final String ownerName;
  final String businessName;
  final String phoneNumber;
  final List<SocialAccount> socialAccounts;
  final List<ServiceProvided> services;
  final DealDetails? dealDetails;

  Customer({
    required this.docId,
    required this.ownerName,
    required this.businessName,
    required this.phoneNumber,
    required this.socialAccounts,
    required this.services,
    this.dealDetails,
  });

  factory Customer.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final List<dynamic> rawAccounts = data['socialAccounts'] ?? [];
    final List<dynamic> rawServices = data['services'] ?? [];
    final rawDeal = data['dealDetails'];
    return Customer(
      docId: doc.id,
      ownerName: data['ownerName'] ?? '',
      businessName: data['businessName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      socialAccounts: rawAccounts
          .map((e) => SocialAccount.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      services: rawServices
          .map((e) => ServiceProvided.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      dealDetails: rawDeal != null
          ? DealDetails.fromMap(Map<String, dynamic>.from(rawDeal))
          : null,
    );
  }
}