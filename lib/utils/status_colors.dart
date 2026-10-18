import 'package:flutter/material.dart';

import '../models/payment.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';

Color transactionStatusColor(TransactionStatus status) => switch (status) {
  TransactionStatus.pending => AppColors.warning,
  TransactionStatus.inProgress => AppColors.info,
  TransactionStatus.completed => AppColors.success,
  TransactionStatus.cancelled => AppColors.error,
};

Color paymentStatusColor(TransactionPaymentStatus status) => switch (status) {
  TransactionPaymentStatus.pending => AppColors.warning,
  TransactionPaymentStatus.paid => AppColors.success,
  TransactionPaymentStatus.failed => AppColors.error,
  TransactionPaymentStatus.refunded => AppColors.secondaryText,
  TransactionPaymentStatus.partiallyRefunded => AppColors.secondaryText,
};

Color changeRequestStatusColor(ChangeRequestStatus status) => switch (status) {
  ChangeRequestStatus.none => AppColors.secondaryText,
  ChangeRequestStatus.pending => AppColors.warning,
  ChangeRequestStatus.approved => AppColors.success,
  ChangeRequestStatus.rejected => AppColors.error,
};

Color paymentGatewayStatusColor(PaymentGatewayStatus status) =>
    switch (status) {
      PaymentGatewayStatus.pending => AppColors.warning,
      PaymentGatewayStatus.paid => AppColors.success,
      PaymentGatewayStatus.failed => AppColors.error,
      PaymentGatewayStatus.expired => AppColors.error,
      PaymentGatewayStatus.refunded => AppColors.secondaryText,
    };
