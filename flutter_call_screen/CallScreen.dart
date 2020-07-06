import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_websocket/services/Socket.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart';


class CallScreen extends StatefulWidget {
  Socket socket;
  CallScreen({this.socket});

final String title='demo';

@override
_CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  SocketClass socketClass;
  bool _offer = false;
  bool dialer=false;
  bool reciever=false;
  RTCPeerConnection _peerConnection;
  MediaStream _localStream;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

  final sdpController = TextEditingController();

  @override
  dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    initRenderers();
    socketClass = SocketClass();

    socketClass.socket.emit('connect_to_call', ['From Mobile']);

    socketClass.socket.on('connectToCallRoom', (data){
      if(data!=null)
      {
      print(data);
        if(data=='connecting'){
           dialer=true;

        }
        else if(data=='connected'){
          if(dialer){
            print('========>');
            _createOffer();
          }
        }

      }
      socketClass.socket.on('callDetails_to_phn', (importantData) {
        print(importantData['type']);
        if(importantData['type']=='set_sdp_reciever'){
          _setRemoteDescription(importantData['sdp']);
        }

      });
    });
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
    super.initState();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();



  }

  void _createOffer() async {
    print('creating offer..........');
    RTCSessionDescription description =
    await _peerConnection.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp);
    _offer = true;
    socketClass.socket.emit('callDetails_to_server',['offer_sdp',json.encode(session)]);
    // print(json.encode({
    //       'sdp': description.sdp.toString(),
    //       'type': description.type.toString(),
    //     }));

    _peerConnection.setLocalDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description =
    await _peerConnection.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp);
   // print(json.encode(session));

    // print(json.encode({
    //       'sdp': description.sdp.toString(),
    //       'type': description.type.toString(),
    //     }));
    socketClass.socket.emit('callDetails_to_server',['ans_sdp',json.encode(session)]);
    _peerConnection.setLocalDescription(description);
  }

  void _setRemoteDescription(var sdpJSON) async {
    print('*********setting SDP**********'+sdpJSON);
    dynamic session = await jsonDecode(sdpJSON);

    String sdp = write(session, null);

    // RTCSessionDescription description =
    //     new RTCSessionDescription(session['sdp'], session['type']);
    RTCSessionDescription description =
    new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());

    await _peerConnection.setRemoteDescription(description);
    print('*********setting SDP**********');
  }

  void _addCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate =
    new RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection.addCandidate(candidate);
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc = await createPeerConnection(configuration, offerSdpConstraints);
    // if (pc != null) print(pc);
    pc.addStream(_localStream);

    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        }));
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
      },
    };

    MediaStream stream = await navigator.getUserMedia(mediaConstraints);

    // _localStream = stream;
    _localRenderer.srcObject = stream;
    _localRenderer.mirror = true;

    // _peerConnection.addStream(stream);

    return stream;
  }

  SizedBox videoRenderers() => SizedBox(
      height: 210,
      child: Row(children: [
        Flexible(
          child: new Container(
              key: new Key("local"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_localRenderer)
          ),
        ),
        Flexible(
          child: new Container(
              key: new Key("remote"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_remoteRenderer)),
        )
      ]));

  Row offerAndAnswerButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        new RaisedButton(
          // onPressed: () {
          //   return showDialog(
          //       context: context,
          //       builder: (context) {
          //         return AlertDialog(
          //           content: Text(sdpController.text),
          //         );
          //       });
          // },
          onPressed: _createOffer,
          child: Text('Offer'),
          color: Colors.amber,
        ),
        RaisedButton(
          onPressed: _createAnswer,
          child: Text('Answer'),
          color: Colors.amber,
        ),
      ]);

  Row sdpCandidateButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        RaisedButton(
          onPressed: null,
          child: Text('Set Remote Desc'),
          color: Colors.amber,
        ),
        RaisedButton(
          onPressed: _addCandidate,
          child: Text('Add Candidate'),
          color: Colors.amber,
        )
      ]);

  Padding sdpCandidatesTF() => Padding(
    padding: const EdgeInsets.all(16.0),
    child: TextField(
      controller: sdpController,
      keyboardType: TextInputType.multiline,
      maxLines: 4,
      maxLength: TextField.noMaxLength,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Container(
            child: Column(children: [
              videoRenderers(),
              offerAndAnswerButtons(),
              sdpCandidatesTF(),
              sdpCandidateButtons(),
            ])));
  }
  void printWrapped(String text) {
    Clipboard.setData(ClipboardData(text: text));
    widget.socket.emit('printing',[text]);
  }
}