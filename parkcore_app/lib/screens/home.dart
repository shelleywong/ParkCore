import 'package:flutter/material.dart';
import 'package:parkcore_app/navigate/menu_drawer.dart';
import 'package:parkcore_app/navigate/parkcore_button.dart';
import 'package:parkcore_app/screens/parkcore_text.dart';
import 'package:geocoder/geocoder.dart';
import 'package:parkcore_app/parking/find_parking.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  // This widget is the home page of your application. It is stateful: it has a
  // State object (defined below) that contains fields that affect how it looks.
  // This class is the configuration for the state. It holds the values (title)
  // provided by the parent (App widget) and used by the build method of the
  // State. Fields in a Widget subclass are always marked 'final'.

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _searchKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  final _input = MyInput();
  final _loc = MyLoc();
  final _city = MyCity();
  final _coordinates = MyCoordinates();
  final found = LocFound();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          key: Key('homeAppTitle'),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).backgroundColor,
        actions: <Widget>[
          LogoButton(),
        ],
      ),
      drawer: MenuDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
            children: <Widget>[
              Form(
                key: _searchKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: SearchBar(),
                ),
              ),
              SizedBox(height: 10),
              _input.input == 'none' ? Text('') : SearchReturn(),
              SizedBox(height: 50),
              ParkCoreText(),
            ],
          ),
        ),
      ),
    );
  }

  // Search Bar includes Search By Location field and Search Button
  List<Widget> SearchBar() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            flex: 5,
            fit: FlexFit.tight,
            child: Column(
              children: [
                SearchField(),
              ],
            ),
          ),
          Flexible(
            flex: 1,
            fit: FlexFit.tight,
            child: Column(
              children: [
                SearchButton(),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  // Search By Location field
  Widget SearchField() {
    return TextFormField(
      autofocus: true,
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by location',
        hintStyle: TextStyle(
          fontSize: 18.0,
          color: Theme.of(context).backgroundColor,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).accentColor,
          ),
        ),
      ),
    );
  }

  // Search By Location Button
  Widget SearchButton() {
    return Ink(
      padding: EdgeInsets.all(3.0),
      decoration: const ShapeDecoration(
        color: Color(0xFF7E57C2),
        shape: CircleBorder(),
      ),
      child: IconButton(
        icon: Icon(
          Icons.search,
          size: 35.0,
        ),
        color: Colors.white,
        tooltip: 'Search for parking space locations',
        onPressed: () {
          submitSearch(_searchController.text);
        },
      ),
    );
  }

  // When Search Button is clicked, try to find a location (set of coordinates)
  void submitSearch(String search) async {
    //assert(search != null);
    if(getLocation() != null) {
      setState(() {
        _input.input = 'Find parking near: ' + search;
      });
    }
  }

  // Show Search Results
  Widget SearchReturn() {
    return Column(
      key: Key('searchResult'),
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(_input.input),
        SizedBox(height: 10.0),
        Divider(
          color: Colors.black,
          height: 20,
        ),
        FoundResults(),
        Divider(
          color: Colors.black,
          height: 20,
        ),
      ],
    );
  }

  // If Search is successful, show found location & button to go to map;
  // else, show error message
  Widget FoundResults() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 5,
          fit: FlexFit.tight,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text(
                  _loc.location,
                  style: Theme.of(context).textTheme.headline3,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          flex: 1,
          fit: FlexFit.tight,
          child: Column(
            children: [
              found.found ? RaisedButton(
                child: Text('Go!'),
                onPressed: () {
                  Navigator.push(context,
                    MaterialPageRoute(
                      builder: (context) => FindParking(
                        colRef: Firestore.instance.collection('parkingSpaces'),
                        title: 'Find Parking',
                        city: _city.city,
                        latlong: _coordinates.coordinates ?? '{39.7285,-121.8375}',
                      ),
                    ),
                  );
                },
                color: Theme.of(context).backgroundColor,
                textColor: Colors.white,
              )
              :Opacity(
                key: Key('failedSearch'),
                opacity: 0.3,
                child: SvgPicture.asset(
                  'assets/Acorns.svg',
                  width: 60,
                  fit: BoxFit.cover,
                  semanticsLabel: 'Acorns image',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool getLocation() {
    try{
      validateLocation();
      return true;
    }
    catch(e){
      //print('Error occurred: $e');
      return false;
    }
  }

  // Use geocoder to search for a location that matches search result input
  void validateLocation() async {
    var loc_input = _searchController.text;
    try {
      var addresses = await Geocoder.local.findAddressesFromQuery(loc_input);
      var first = addresses.first; // Get Address
      var addr = getSplitAddress(first.addressLine.toString()); // String []

      setState(() {
        found.found = setLoc(first, addr);
      });
    }
    catch (e) {
      setState(() {
        found.found = locNotFound(loc_input);
      });
    }
  }

  // geocoder has different results depending on the address details given
  // extracting city from the address so find_parking goes to specified city
  bool setLoc(Address first, List<String> addr){
    if(addr.length <= 3){
      _city.city = addr[0];  // when addr is: city, state, country
    }
    else{
      _city.city = addr[1]; // when addr is: address, city, state, country
    }
    _loc.location = '${first.addressLine}';
    _coordinates.coordinates = first.coordinates.toString();
    return true;
  }

  // If geocoder fails to find the location searched for,
  // set 'found' to false, and set search failure message
  bool locNotFound(String loc_input){
    _loc.location = 'Sorry, no search results for "' + loc_input + '".';
    return false;
  }

  List<String> getSplitAddress(String address){
    return address.split(', ');
  }
}

class MyInput {
  String _input = 'none';
  String get input => _input;
  set input(String input) => _input = input;
}

class MyLoc {
  String _loc = '';
  String get location => _loc;
  set location(String loc) => _loc = loc;
}

class MyCity {
  String _city = '';
  String get city => _city;
  set city(String city) => _city = city;
}

class MyCoordinates {
  String _coordinates = '';
  String get coordinates => _coordinates;
  set coordinates(String coordinates) => _coordinates = coordinates;
}

class LocFound {
  bool _found = false;
  bool get found => _found;
  set found(bool found) => _found = found;
}
