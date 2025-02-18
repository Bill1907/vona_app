class WebRTCConfig {
  static const Map<String, dynamic> configuration = {
    "iceServers": [
      {"urls": "stun:stun.l.google.com:19302"},
      {
        "urls": [
          "turn:turn.vona.app:3478?transport=udp",
          "turn:turn.vona.app:3478?transport=tcp"
        ],
        "username": "vona",
        "credential": "vona2024" // TODO: Move to secure configuration
      }
    ],
    "sdpSemantics": "unified-plan",
    "iceCandidatePoolSize": 10,
    "bundlePolicy": "max-bundle",
    "rtcpMuxPolicy": "require",
    "enableDtlsSrtp": true
  };

  static const Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true,
    },
    "optional": [],
  };

  static const Map<String, dynamic> mediaConstraints = {
    'audio': true,
    'video': {
      'mandatory': {
        'minWidth': '640',
        'minHeight': '480',
        'minFrameRate': '30',
      },
      'facingMode': 'user',
      'optional': [],
    }
  };
}
