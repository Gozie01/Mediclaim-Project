// PureChain network configuration
const String pureChainRpc = 'https://purechainnode.com';
const int pureChainId = 900520900520;

class ContractAddresses {
  ContractAddresses._();

  static const String zkConsentVerifier =
      '0x6A36Ee5E14524Fa5599847ad12eca7d03D66C015';
  static const String hospitalRegistry =
      '0xD02B2Bcd7389A86BC107B2b051c741E37f0963d5';
  static const String patientProfile =
      '0x975E62Cb81B0a51218D9c2078D65fb4A1Bd38790';
  static const String medicalRecord =
      '0xe21beb671c9d52DfA3871eb0f370B5999183a09e';
  static const String insurancePolicy =
      '0x679bEDDF7cd77D812121421520E83f94715B0d02';
  static const String multiOracleConsensus =
      '0x7c05dac418A17291f4C3d661Ddce4270694DA363';
  static const String mediClaim =
      '0xc56Abe0629d263d1A74e047cFcf221209566509F';
}

class DemoAccounts {
  DemoAccounts._();

  static const String patientHospitalInsurer =
      '0x973B368ff10500168b81d744B4f35c6f42de91c2';
  static const String doctor =
      '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
  static const String nurse =
      '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC';
  static const String billing =
      '0x90F79bf6EB2c4f870365E785982E1f101E93b906';

  static const String demoPrivateKey =
      '0xf0b4a73e0aac70e79e9afbba39f65022846876028bc740f8cd909fac484472f0';

  static const Map<String, String> labeledAccounts = {
    'Patient / Hospital / Insurer': patientHospitalInsurer,
    'Doctor': doctor,
    'Nurse': nurse,
    'Billing': billing,
  };
}

class ContractAbis {
  ContractAbis._();

  static const List<Map<String, dynamic>> patientProfile = [
    {
      'name': 'isRegistered',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'patient', 'type': 'address'}
      ],
      'outputs': [
        {'name': '', 'type': 'bool'}
      ],
    },
    {
      'name': 'getPatient',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'patient', 'type': 'address'}
      ],
      'outputs': [
        {
          'name': '',
          'type': 'tuple',
          'components': [
            {'name': 'did', 'type': 'string'},
            {'name': 'fhirId', 'type': 'string'},
            {'name': 'name', 'type': 'string'},
            {'name': 'dateOfBirth', 'type': 'string'},
            {'name': 'bloodType', 'type': 'string'},
            {'name': 'emergencyContact', 'type': 'string'},
            {'name': 'ipfsCid', 'type': 'string'},
            {'name': 'dataHash', 'type': 'bytes32'},
            {'name': 'registeredAt', 'type': 'uint256'},
            {'name': 'lastUpdated', 'type': 'uint256'},
            {'name': 'active', 'type': 'bool'},
            {'name': 'erased', 'type': 'bool'},
          ]
        }
      ],
    },
    {
      'name': 'getGrantedHospitals',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'patient', 'type': 'address'}
      ],
      'outputs': [
        {'name': '', 'type': 'address[]'}
      ],
    },
    {
      'name': 'registerPatient',
      'type': 'function',
      'stateMutability': 'nonpayable',
      'inputs': [
        {'name': 'did', 'type': 'string'},
        {'name': 'fhirId', 'type': 'string'},
        {'name': 'name', 'type': 'string'},
        {'name': 'dob', 'type': 'string'},
        {'name': 'bloodType', 'type': 'string'},
        {'name': 'ipfsCid', 'type': 'string'},
        {'name': 'dataHash', 'type': 'bytes32'},
      ],
      'outputs': [],
    },
    {
      'name': 'grantAccess',
      'type': 'function',
      'stateMutability': 'nonpayable',
      'inputs': [
        {'name': 'hospital', 'type': 'address'},
        {'name': 'role', 'type': 'uint8'},
        {'name': 'category', 'type': 'uint8'},
        {'name': 'writeAccess', 'type': 'bool'},
        {'name': 'durationSeconds', 'type': 'uint256'},
      ],
      'outputs': [],
    },
    {
      'name': 'revokeAllFromHospital',
      'type': 'function',
      'stateMutability': 'nonpayable',
      'inputs': [
        {'name': 'hospital', 'type': 'address'}
      ],
      'outputs': [],
    },
  ];

  static const List<Map<String, dynamic>> hospitalRegistry = [
    {
      'name': 'getApprovedHospitals',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [],
      'outputs': [
        {'name': '', 'type': 'address[]'}
      ],
    },
    {
      'name': 'getHospital',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'hospital', 'type': 'address'}
      ],
      'outputs': [
        {
          'name': '',
          'type': 'tuple',
          'components': [
            {'name': 'name', 'type': 'string'},
            {'name': 'licenseNumber', 'type': 'string'},
            {'name': 'fhirOrganizationId', 'type': 'string'},
            {'name': 'specialties', 'type': 'string'},
            {'name': 'location', 'type': 'string'},
            {'name': 'adminAddress', 'type': 'address'},
            {'name': 'approved', 'type': 'bool'},
            {'name': 'active', 'type': 'bool'},
            {'name': 'registeredAt', 'type': 'uint256'},
            {'name': 'approvedAt', 'type': 'uint256'},
          ]
        }
      ],
    },
    {
      'name': 'getHospitalStaff',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'hospital', 'type': 'address'}
      ],
      'outputs': [
        {'name': '', 'type': 'address[]'}
      ],
    },
    {
      'name': 'getPersonnel',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'hospital', 'type': 'address'},
        {'name': 'personnel', 'type': 'address'},
      ],
      'outputs': [
        {
          'name': '',
          'type': 'tuple',
          'components': [
            {'name': 'name', 'type': 'string'},
            {'name': 'role', 'type': 'uint8'},
            {'name': 'staffId', 'type': 'string'},
            {'name': 'active', 'type': 'bool'},
            {'name': 'addedAt', 'type': 'uint256'},
          ]
        }
      ],
    },
    {
      'name': 'registerHospital',
      'type': 'function',
      'stateMutability': 'nonpayable',
      'inputs': [
        {'name': 'name', 'type': 'string'},
        {'name': 'licenseNumber', 'type': 'string'},
        {'name': 'fhirOrganizationId', 'type': 'string'},
        {'name': 'specialties', 'type': 'string'},
        {'name': 'location', 'type': 'string'},
      ],
      'outputs': [],
    },
    {
      'name': 'addPersonnel',
      'type': 'function',
      'stateMutability': 'nonpayable',
      'inputs': [
        {'name': 'personnelAddress', 'type': 'address'},
        {'name': 'role', 'type': 'uint8'},
        {'name': 'name', 'type': 'string'},
        {'name': 'staffId', 'type': 'string'},
      ],
      'outputs': [],
    },
  ];

  static const List<Map<String, dynamic>> mediClaim = [
    {
      'name': 'getPatientClaims',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'patient', 'type': 'address'}
      ],
      'outputs': [
        {'name': '', 'type': 'bytes32[]'}
      ],
    },
    {
      'name': 'getHospitalClaims',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'hospital', 'type': 'address'}
      ],
      'outputs': [
        {'name': '', 'type': 'bytes32[]'}
      ],
    },
    {
      'name': 'getPendingApprovals',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'patient', 'type': 'address'}
      ],
      'outputs': [
        {'name': '', 'type': 'bytes32[]'}
      ],
    },
    {
      'name': 'getClaim',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'claimId', 'type': 'bytes32'}
      ],
      'outputs': [
        {
          'name': '',
          'type': 'tuple',
          'components': [
            {'name': 'claimId', 'type': 'bytes32'},
            {'name': 'hospital', 'type': 'address'},
            {'name': 'patient', 'type': 'address'},
            {'name': 'policyHash', 'type': 'bytes32'},
            {'name': 'amount', 'type': 'uint256'},
            {'name': 'ipfsTreatmentHash', 'type': 'string'},
            {'name': 'icdCode', 'type': 'string'},
            {'name': 'cptCode', 'type': 'string'},
            {'name': 'fhirClaimId', 'type': 'string'},
            {'name': 'treatmentSummary', 'type': 'string'},
            {'name': 'status', 'type': 'uint8'},
            {'name': 'draftedAt', 'type': 'uint256'},
            {'name': 'updatedAt', 'type': 'uint256'},
            {'name': 'rejectionReason', 'type': 'string'},
          ]
        }
      ],
    },
    {
      'name': 'getSystemStats',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [],
      'outputs': [
        {'name': 'totalDrafted', 'type': 'uint256'},
        {'name': 'pendingApproval', 'type': 'uint256'},
        {'name': 'underReview', 'type': 'uint256'},
        {'name': 'approved', 'type': 'uint256'},
        {'name': 'fraudFlagged', 'type': 'uint256'},
        {'name': 'totalPaid', 'type': 'uint256'},
        {'name': 'totalPaidAmount', 'type': 'uint256'},
      ],
    },
    {
      'name': 'draftClaim',
      'type': 'function',
      'stateMutability': 'nonpayable',
      'inputs': [
        {'name': 'patient', 'type': 'address'},
        {'name': 'policyHash', 'type': 'bytes32'},
        {'name': 'amount', 'type': 'uint256'},
        {'name': 'ipfsTreatmentHash', 'type': 'string'},
        {'name': 'icdCode', 'type': 'string'},
        {'name': 'cptCode', 'type': 'string'},
        {'name': 'fhirClaimId', 'type': 'string'},
        {'name': 'treatmentSummary', 'type': 'string'},
      ],
      'outputs': [
        {'name': '', 'type': 'bytes32'}
      ],
    },
    {
      'name': 'approveClaimByPatient',
      'type': 'function',
      'stateMutability': 'nonpayable',
      'inputs': [
        {'name': 'claimId', 'type': 'bytes32'}
      ],
      'outputs': [],
    },
    {
      'name': 'rejectClaimByPatient',
      'type': 'function',
      'stateMutability': 'nonpayable',
      'inputs': [
        {'name': 'claimId', 'type': 'bytes32'},
        {'name': 'reason', 'type': 'string'},
      ],
      'outputs': [],
    },
  ];

  static const List<Map<String, dynamic>> insurancePolicy = [
    {
      'name': 'getPatientPolicies',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'patient', 'type': 'address'}
      ],
      'outputs': [
        {'name': '', 'type': 'bytes32[]'}
      ],
    },
    {
      'name': 'getPolicy',
      'type': 'function',
      'stateMutability': 'view',
      'inputs': [
        {'name': 'policyHash', 'type': 'bytes32'}
      ],
      'outputs': [
        {'name': 'policyId', 'type': 'string'},
        {'name': 'insurer', 'type': 'address'},
        {'name': 'patient', 'type': 'address'},
        {'name': 'coverageAmount', 'type': 'uint256'},
        {'name': 'premium', 'type': 'uint256'},
        {'name': 'startDate', 'type': 'uint256'},
        {'name': 'endDate', 'type': 'uint256'},
        {'name': 'active', 'type': 'bool'},
        {'name': 'claimed', 'type': 'bool'},
      ],
    },
  ];
}
