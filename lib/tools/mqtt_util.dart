

import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:dio/dio.dart';

class MqttUtil{
  static const String restapi= "https://api.cn1.mqtt.chat/app/$appID/";  //环信MQTT REST API地址 通过console后台[MQTT]->[服务概览]->[服务配置]下[REST API地址]获取

  static const String endpoint= "**.**.**.**"; //环信MQTT服务器地址 通过console后台[MQTT]->[服务概览]->[服务配置]下[连接地址]获取
  static const int port = 1883; // 协议服务端口 通过console后台[MQTT]->[服务概览]->[服务配置]下[连接端口]获取
  static const String appID= "**"; // appID 通过console后台[MQTT]->[服务概览]->[服务配置]下[AppID]获取
  static late String deviceId ;// 自定义deviceID
  static late String clientID ;// deviceId + '@' + appID
  static const String appClientId= "**"; //开发者ID 通过console后台[应用概览]->[应用详情]->[开发者ID]下[ Client ID]获取
  static const String appClientSecret= "**"; // 开发者密钥 通过console后台[应用概览]->[应用详情]->[开发者ID]下[ ClientSecret]获取

  static MqttServerClient? _client;

  static void init() async{
    deviceId = "deviceId";
    clientID = "$deviceId@$appID";

    Dio dio = Dio();
    ///首先获取App Token
    Response<Map<String,dynamic>> data = await dio.post("${restapi}openapi/rm/app/token",data: {"appClientId": appClientId, "appClientSecret": appClientSecret});
    var token = (data.data!["body"] as Map<String, dynamic> )["access_token"];
    ///然后根据App Token获取User Token，User Token作为连接服务的密码
    Response<Map<String,dynamic>> data2 = await dio.post("${restapi}openapi/rm/user/token",data: {"username": "username", "cid": clientID},options: Options(headers:  <String, dynamic>{"Authorization": token}));
    var mqtttoken = (data2.data!["body"] as Map<String, dynamic> )["access_token"];


    var client = MqttServerClient.withPort(endpoint, clientID, port);
    _client = client;
    /// 是否打印mqtt日志信息
    client.logging(on: true);
    /// 设置协议版本，默认是3.1，根据服务器需要的版本来设置
    /// _client.setProtocolV31();
    client.setProtocolV311();
    /// 保持连接ping-pong周期。默认不设置时关闭。
    client.keepAlivePeriod = 60;
    /// 设置自动重连
    client.doAutoReconnect();
    /// 设置超时时间，单位：毫秒
    client.connectTimeoutPeriod = 60000;
    /// 连接成功回调
    client.onConnected = _onConnected;
    /// 连接断开回调
    client.onDisconnected = _onDisconnected;
    /// 取消订阅回调
    client.onUnsubscribed = _onUnsubscribed;
    /// 订阅成功回调
    client.onSubscribed = _onSubscribed;
    /// 订阅失败回调
    client.onSubscribeFail = _onSubscribeFail;
    /// ping pong响应回调
    client.pongCallback = _pong;
    client.connect("username",mqtttoken);

  }

  static void _onConnected() {
    print("连接成功....");
    _initTopic();
  }

  static void _onDisconnected() {
    print("连接断开");
  }

  static void _onUnsubscribed(String? topic) {
    print("取消订阅 $topic");
  }

  static void _onSubscribed(String topic) {
    print("订阅 $topic 成功");
  }

  static void _onSubscribeFail(String topic) {
    print("订阅主题: $topic 失败");
  }

  static void _pong() {
    print("Ping的响应");
  }
  static const _scribeTopic = "topic/test";

  static void _initTopic(){
    /// 需要订阅的主题
    ///订阅主题，并设置qos
    _client?.subscribe(_scribeTopic, MqttQos.atLeastOnce);

    _client?.updates?.listen((event) {
      var recvMessage = event[0].payload as MqttPublishMessage;

      print("原始数据-----：${recvMessage.payload.message}");
      /// 转换成字符串
      print(
          "接收到了主题${event[0].topic}的消息： ${const Utf8Decoder().convert(recvMessage.payload.message)}");
    });
  }

  static void publish(){
    var builder = MqttClientPayloadBuilder();
    builder.addUTF8String("This is a message");
    _client?.publishMessage(_scribeTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  static void dispose(){
    if (_client != null) {
      _client?.disconnect();
      _client = null;
    }
  }

}