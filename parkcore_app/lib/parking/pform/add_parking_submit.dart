import 'package:flutter/material.dart';
import 'package:parkcore_app/navigate/menu_drawer.dart';
import 'package:parkcore_app/models/ParkingData.dart';
import 'package:parkcore_app/models/ParkingData2.dart';
import 'package:parkcore_app/models/ParkingData3.dart';
import 'package:parkcore_app/models/CurrentUser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'pform_helpers.dart';

class AddParkingSubmit extends StatefulWidget {
  AddParkingSubmit({Key key,
    this.parkingData, this.parkingData2, this.parkingData3, this.curUser
  }) : super(key: key);

  // This widget is the 'add parking' page of the app. It is stateful: it has a
  // State object (defined below) that contains fields that affect how it looks.
  // This class is the configuration for the state. It holds the values (title)
  // provided by the parent (App widget) and used by the build method of the
  // State. Fields in a Widget subclass are always marked 'final'.

  final ParkingData parkingData;
  final ParkingData2 parkingData2;
  final ParkingData3 parkingData3;
  final CurrentUser curUser;

  @override
  _MyAddParkingSubmitState createState() => _MyAddParkingSubmitState();
}

class _MyAddParkingSubmitState extends State<AddParkingSubmit> {
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  FormError formError = FormError();
  final ImagePicker _picker = ImagePicker();
  File _imageFile;
  String _downloadURL;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // build(): rerun every time setState is called (e.g. for stateful methods)
    // Rebuild anything that needs updating instead of having to individually
    // change instances of widgets.
    // Build a Form widget using the _formKey created above.
    return Scaffold(
      key: _scaffoldKey,
      appBar: parkingFormAppBar(),
      drawer: MenuDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('Part 5 of 5'),
              SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: buildImages(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> buildImages() {
    return [
      showImage(),
      SizedBox(height: 10),
      Row(
        children: <Widget>[
          getImageType('camera'),
          SizedBox(width: 10),
          getImageType('gallery'),
        ],
      ),
      SizedBox(height: 10),
      submitParking(),
      SizedBox(height: 10),
      restart(context),
    ];
  }

  // Page 4 Parking Form Widgets (Image and Submit)

  Widget showImage() {
    return Center(
      child: _imageFile == null
          ? Text(
        'No image selected.',
        style: Theme.of(context).textTheme.headline3,
      )
          : Image.file(_imageFile),
    );
  }

  Widget getImageType(String type) {
    return Expanded(
      child: FormField<File>(
        //validator: validateImage,
        builder: (FormFieldState<File> state) {
          return RaisedButton(
            child: Icon(
              type == 'camera' ? Icons.photo_camera : Icons.photo_library,
            ),
            onPressed: () =>
            type == 'camera' ?
            getUserImage(ImageSource.camera) : getUserImage(ImageSource.gallery),
            color: Theme.of(context).backgroundColor,
            textColor: Colors.white,
          );
        },
      ),
    );
  }

  // Select an image via gallery or camera
  Future<void> getUserImage(ImageSource source) async {
    var selected = await _picker.getImage(source: source);

    setState(() {
      _imageFile = File(selected.path);
    });
  }

  // Get a unique ID for each image upload
  Future<void> getUniqueFile() async {
    final uuid = Uuid().v1();
    _downloadURL = await _uploadFile(uuid);
  }

  // get download URL for image files
  Future<String> _uploadFile(filename) async {
    //StorageReference
    final ref = FirebaseStorage.instance.ref().child('$filename.jpg');
    //StorageUploadTask
    final uploadTask = ref.putFile(
      _imageFile,
      StorageMetadata(
        contentLanguage: 'en',
      ),
    );

    final downloadURL =
    await (await uploadTask.onComplete).ref.getDownloadURL();
    return downloadURL.toString();
  }

  Widget submitParking() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        RaisedButton(
          key: Key('submit'),
          onPressed: () {
            final form = _formKey.currentState;
            form.save();

            try {
              createParkingSpace();
              print('parking space added to database');
              Navigator.pushReplacementNamed(context, '/form_success');
            }
            catch (e) {
              print('Error occurred: $e');
            }
          },
          child: Text(
            'Submit',
            style: Theme.of(context).textTheme.headline4,
          ),
          color: Theme.of(context).accentColor,
        ),
      ],
    );
  }

  // Create ParkingSpaces database entry
  Future<void> createParkingSpace() async {
    try {
      await getUniqueFile();
    } catch (e) {
      print('Error occurred: $e');
    }

    var allParkingData = {
      'title': widget.parkingData.title,
      'address': widget.parkingData.address,
      'city': widget.parkingData.city_format,
      'state': widget.parkingData.state,
      'zip': widget.parkingData.zip,
      'coordinates': widget.parkingData.coordinates, // generated from the input address
      'coordinates_r': widget.parkingData.coord_rand, // random coordinates near actual address
      'uid': widget.parkingData.uid, // parkingSpace owner is the current user
      'size': widget.parkingData2.size,
      'type': widget.parkingData2.type,
      'driveway': widget.parkingData2.driveway,
      'spacetype': widget.parkingData2.spaceType,
      'amenities': widget.parkingData2.myAmenities.toString(),
      'spacedetails': widget.parkingData2.details,
      'days': widget.parkingData3.myDays.toString(),
      'starttime': widget.parkingData3.startTime,
      'endtime': widget.parkingData3.endTime,
      'monthprice': widget.parkingData3.price,
      'downloadURL': _downloadURL, // for the image (put in firebase storage)
      'reserved': [].toString(), // list of UIDs (if reserved, starts empty)
      'cur_tenant': '', // current tenant (a UID, or empty if spot is available)
    };

    await Firestore.instance.runTransaction((transaction) async {
      //CollectionReference
      var ref = Firestore.instance.collection('parkingSpaces');
      await ref.add(allParkingData);
    });
  }
}
