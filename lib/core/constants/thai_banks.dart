import 'package:flutter/material.dart';

class ThaiBank {
  final String code;
  final String name;
  final String shortName;
  final Color color;
  final String logoCode; // Abbreviation for badge

  const ThaiBank({
    required this.code,
    required this.name,
    required this.shortName,
    required this.color,
    required this.logoCode,
  });
}

const List<ThaiBank> kThaiBanks = [
  ThaiBank(
    code: 'KBANK',
    name: 'ธนาคารกสิกรไทย (Kasikornbank)',
    shortName: 'กสิกรไทย',
    color: Color(0xFF138F2D),
    logoCode: 'K+',
  ),
  ThaiBank(
    code: 'SCB',
    name: 'ธนาคารไทยพาณิชย์ (Siam Commercial Bank)',
    shortName: 'ไทยพาณิชย์',
    color: Color(0xFF4E2E7F),
    logoCode: 'SCB',
  ),
  ThaiBank(
    code: 'BBL',
    name: 'ธนาคารกรุงเทพ (Bangkok Bank)',
    shortName: 'กรุงเทพ',
    color: Color(0xFF1E3F8B),
    logoCode: 'BBL',
  ),
  ThaiBank(
    code: 'KTB',
    name: 'ธนาคารกรุงไทย (Krungthai Bank)',
    shortName: 'กรุงไทย',
    color: Color(0xFF00A6E6),
    logoCode: 'KTB',
  ),
  ThaiBank(
    code: 'TTB',
    name: 'ธนาคารทหารไทยธนชาต (TMBThanachart Bank)',
    shortName: 'ทีทีบี',
    color: Color(0xFF002D62),
    logoCode: 'TTB',
  ),
  ThaiBank(
    code: 'BAY',
    name: 'ธนาคารกรุงศรีอยุธยา (Bank of Ayudhya)',
    shortName: 'กรุงศรี',
    color: Color(0xFFFEC400),
    logoCode: 'BAY',
  ),
  ThaiBank(
    code: 'GSB',
    name: 'ธนาคารออมสิน (Government Savings Bank)',
    shortName: 'ออมสิน',
    color: Color(0xFFEB1985),
    logoCode: 'GSB',
  ),
  ThaiBank(
    code: 'BAAC',
    name: 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร (ธ.ก.ส.)',
    shortName: 'ธ.ก.ส.',
    color: Color(0xFF006838),
    logoCode: 'BAAC',
  ),
  ThaiBank(
    code: 'KKP',
    name: 'ธนาคารเกียรตินาคินภัทร (Kiatnakin Phatra Bank)',
    shortName: 'เกียรตินาคิน',
    color: Color(0xFF6B2D82),
    logoCode: 'KKP',
  ),
  ThaiBank(
    code: 'CIMB',
    name: 'ธนาคารซีไอเอ็มบีไทย (CIMB Thai Bank)',
    shortName: 'ซีไอเอ็มบี',
    color: Color(0xFF7E0000),
    logoCode: 'CIMB',
  ),
  ThaiBank(
    code: 'UOB',
    name: 'ธนาคารยูโอบี (United Overseas Bank)',
    shortName: 'ยูโอบี',
    color: Color(0xFF0B2265),
    logoCode: 'UOB',
  ),
];
