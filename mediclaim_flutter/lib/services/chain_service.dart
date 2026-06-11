import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:convert/convert.dart';

import '../constants/contracts.dart';

class ChainService {
  ChainService._internal();
  static final ChainService instance = ChainService._internal();

  late final Web3Client _client;
  final Map<String, DeployedContract> _contractCache = {};

  ChainService() {
    _client = Web3Client(pureChainRpc, http.Client());
  }

  Web3Client get ethClient => _client;

  // ---------------------------------------------------------------------------
  // Contract helpers
  // ---------------------------------------------------------------------------

  DeployedContract getContract(String name) {
    if (_contractCache.containsKey(name)) {
      return _contractCache[name]!;
    }

    late String address;
    late List<Map<String, dynamic>> abiJson;

    switch (name) {
      case 'patientProfile':
        address = ContractAddresses.patientProfile;
        abiJson = ContractAbis.patientProfile;
        break;
      case 'hospitalRegistry':
        address = ContractAddresses.hospitalRegistry;
        abiJson = ContractAbis.hospitalRegistry;
        break;
      case 'mediClaim':
        address = ContractAddresses.mediClaim;
        abiJson = ContractAbis.mediClaim;
        break;
      case 'insurancePolicy':
        address = ContractAddresses.insurancePolicy;
        abiJson = ContractAbis.insurancePolicy;
        break;
      default:
        throw Exception('Unknown contract: $name');
    }

    final abi = ContractAbi.fromJson(
      _abiToJsonString(abiJson),
      name,
    );
    final contract = DeployedContract(
      abi,
      EthereumAddress.fromHex(address),
    );
    _contractCache[name] = contract;
    return contract;
  }

  String _abiToJsonString(List<Map<String, dynamic>> abi) {
    final buffer = StringBuffer('[');
    for (int i = 0; i < abi.length; i++) {
      buffer.write(_mapToJson(abi[i]));
      if (i < abi.length - 1) buffer.write(',');
    }
    buffer.write(']');
    return buffer.toString();
  }

  String _mapToJson(dynamic value) {
    if (value is Map) {
      final buffer = StringBuffer('{');
      final entries = value.entries.toList();
      for (int i = 0; i < entries.length; i++) {
        buffer.write('"${entries[i].key}":${_mapToJson(entries[i].value)}');
        if (i < entries.length - 1) buffer.write(',');
      }
      buffer.write('}');
      return buffer.toString();
    } else if (value is List) {
      final buffer = StringBuffer('[');
      for (int i = 0; i < value.length; i++) {
        buffer.write(_mapToJson(value[i]));
        if (i < value.length - 1) buffer.write(',');
      }
      buffer.write(']');
      return buffer.toString();
    } else if (value is String) {
      return '"${value.replaceAll('"', '\\"')}"';
    } else if (value is bool) {
      return value.toString();
    } else if (value == null) {
      return 'null';
    } else {
      return value.toString();
    }
  }

  Uint8List _hexToBytes32(String hexStr) {
    final clean = hexStr.startsWith('0x') ? hexStr.substring(2) : hexStr;
    final padded = clean.padLeft(64, '0');
    return Uint8List.fromList(hex.decode(padded));
  }

  // ---------------------------------------------------------------------------
  // PatientProfile calls
  // ---------------------------------------------------------------------------

  Future<bool> isPatientRegistered(String address) async {
    try {
      final contract = getContract('patientProfile');
      final fn = contract.function('isRegistered');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      return result.first as bool;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getPatient(String address) async {
    try {
      final contract = getContract('patientProfile');
      final fn = contract.function('getPatient');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      final tuple = result.first as List;
      return {
        'did': tuple[0]?.toString() ?? '',
        'fhirId': tuple[1]?.toString() ?? '',
        'name': tuple[2]?.toString() ?? '',
        'dateOfBirth': tuple[3]?.toString() ?? '',
        'bloodType': tuple[4]?.toString() ?? '',
        'emergencyContact': tuple[5]?.toString() ?? '',
        'ipfsCid': tuple[6]?.toString() ?? '',
        'dataHash': tuple[7] != null
            ? '0x${hex.encode(tuple[7] as Uint8List)}'
            : '0x',
        'registeredAt': (tuple[8] as BigInt?)?.toInt() ?? 0,
        'lastUpdated': (tuple[9] as BigInt?)?.toInt() ?? 0,
        'active': tuple[10] as bool? ?? false,
        'erased': tuple[11] as bool? ?? false,
      };
    } catch (e) {
      return {};
    }
  }

  Future<List<String>> getGrantedHospitals(String address) async {
    try {
      final contract = getContract('patientProfile');
      final fn = contract.function('getGrantedHospitals');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      final list = result.first as List;
      return list
          .map((e) => (e as EthereumAddress).hexEip55)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // HospitalRegistry calls
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getApprovedHospitals() async {
    try {
      final contract = getContract('hospitalRegistry');
      final fn = contract.function('getApprovedHospitals');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [],
      );
      final addresses = result.first as List;
      final List<Map<String, dynamic>> hospitals = [];
      for (final addr in addresses) {
        final addrStr = (addr as EthereumAddress).hexEip55;
        final info = await getHospital(addrStr);
        if (info.isNotEmpty) {
          hospitals.add({...info, 'address': addrStr});
        }
      }
      return hospitals;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getHospital(String address) async {
    try {
      final contract = getContract('hospitalRegistry');
      final fn = contract.function('getHospital');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      final tuple = result.first as List;
      return {
        'name': tuple[0]?.toString() ?? '',
        'licenseNumber': tuple[1]?.toString() ?? '',
        'fhirOrganizationId': tuple[2]?.toString() ?? '',
        'specialties': tuple[3]?.toString() ?? '',
        'location': tuple[4]?.toString() ?? '',
        'adminAddress': tuple[5] != null
            ? (tuple[5] as EthereumAddress).hexEip55
            : '',
        'approved': tuple[6] as bool? ?? false,
        'active': tuple[7] as bool? ?? false,
        'registeredAt': (tuple[8] as BigInt?)?.toInt() ?? 0,
        'approvedAt': (tuple[9] as BigInt?)?.toInt() ?? 0,
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getPersonnel(
      String hospitalAddress, String personnelAddress) async {
    try {
      final contract = getContract('hospitalRegistry');
      final fn = contract.function('getPersonnel');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [
          EthereumAddress.fromHex(hospitalAddress),
          EthereumAddress.fromHex(personnelAddress),
        ],
      );
      final tuple = result.first as List;
      return {
        'name': tuple[0]?.toString() ?? '',
        'role': (tuple[1] as BigInt?)?.toInt() ?? 0,
        'staffId': tuple[2]?.toString() ?? '',
        'active': tuple[3] as bool? ?? false,
        'addedAt': (tuple[4] as BigInt?)?.toInt() ?? 0,
      };
    } catch (e) {
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // MediClaim calls
  // ---------------------------------------------------------------------------

  Future<List<String>> getPatientClaims(String address) async {
    try {
      final contract = getContract('mediClaim');
      final fn = contract.function('getPatientClaims');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      final list = result.first as List;
      return list.map((e) => '0x${hex.encode(e as Uint8List)}').toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getHospitalClaims(String address) async {
    try {
      final contract = getContract('mediClaim');
      final fn = contract.function('getHospitalClaims');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      final list = result.first as List;
      return list.map((e) => '0x${hex.encode(e as Uint8List)}').toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getPendingApprovals(String address) async {
    try {
      final contract = getContract('mediClaim');
      final fn = contract.function('getPendingApprovals');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      final list = result.first as List;
      return list.map((e) => '0x${hex.encode(e as Uint8List)}').toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getClaim(String claimId) async {
    try {
      final contract = getContract('mediClaim');
      final fn = contract.function('getClaim');
      final bytes = _hexToBytes32(claimId);
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [bytes],
      );
      final tuple = result.first as List;
      return {
        'claimId': claimId,
        'hospital': tuple[1] != null
            ? (tuple[1] as EthereumAddress).hexEip55
            : '',
        'patient': tuple[2] != null
            ? (tuple[2] as EthereumAddress).hexEip55
            : '',
        'policyHash': tuple[3] != null
            ? '0x${hex.encode(tuple[3] as Uint8List)}'
            : '0x',
        'amount': (tuple[4] as BigInt?) ?? BigInt.zero,
        'ipfsTreatmentHash': tuple[5]?.toString() ?? '',
        'icdCode': tuple[6]?.toString() ?? '',
        'cptCode': tuple[7]?.toString() ?? '',
        'fhirClaimId': tuple[8]?.toString() ?? '',
        'treatmentSummary': tuple[9]?.toString() ?? '',
        'status': (tuple[10] as BigInt?)?.toInt() ?? 0,
        'draftedAt': (tuple[11] as BigInt?)?.toInt() ?? 0,
        'updatedAt': (tuple[12] as BigInt?)?.toInt() ?? 0,
        'rejectionReason': tuple[13]?.toString() ?? '',
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      final contract = getContract('mediClaim');
      final fn = contract.function('getSystemStats');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [],
      );
      return {
        'totalDrafted': (result[0] as BigInt?)?.toInt() ?? 0,
        'pendingApproval': (result[1] as BigInt?)?.toInt() ?? 0,
        'underReview': (result[2] as BigInt?)?.toInt() ?? 0,
        'approved': (result[3] as BigInt?)?.toInt() ?? 0,
        'fraudFlagged': (result[4] as BigInt?)?.toInt() ?? 0,
        'totalPaid': (result[5] as BigInt?)?.toInt() ?? 0,
        'totalPaidAmount': result[6] as BigInt? ?? BigInt.zero,
      };
    } catch (e) {
      return {
        'totalDrafted': 0,
        'pendingApproval': 0,
        'underReview': 0,
        'approved': 0,
        'fraudFlagged': 0,
        'totalPaid': 0,
        'totalPaidAmount': BigInt.zero,
      };
    }
  }

  // ---------------------------------------------------------------------------
  // InsurancePolicy calls
  // ---------------------------------------------------------------------------

  Future<List<String>> getPatientPolicies(String address) async {
    try {
      final contract = getContract('insurancePolicy');
      final fn = contract.function('getPatientPolicies');
      final result = await _client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      final list = result.first as List;
      return list.map((e) => '0x${hex.encode(e as Uint8List)}').toList();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  String formatEther(BigInt wei) {
    if (wei == BigInt.zero) return '0.000';
    final etherStr = EtherAmount.fromBigInt(EtherUnit.wei, wei)
        .getValueInUnit(EtherUnit.ether)
        .toStringAsFixed(4);
    return etherStr;
  }

  void dispose() {
    _client.dispose();
  }
}
