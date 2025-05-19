import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for input formatters
import 'package:image_picker/image_picker.dart';
import 'package:Ratedly/resources/auth_methods.dart';
import 'package:Ratedly/responsive/mobile_screen_layout.dart';
import 'package:Ratedly/responsive/responsive_layout.dart';
import 'package:Ratedly/responsive/web_screen_layout.dart';
import 'package:Ratedly/utils/utils.dart';
import 'package:Ratedly/widgets/text_filed_input.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Moved formatter class to top
class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  final int age;

  const ProfileSetupScreen({super.key, required this.age});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  Uint8List? _image;
  bool _isLoading = false;
  bool _isPrivate = false;
  String? _selectedRegion;
  String? _selectedGender;

  final List<String> _regions = [
    'Middle East',
    'North America',
    'Europe',
    'Asia',
    'Africa',
    'South America',
    'United States'
  ];

  final List<String> _genders = ['Male', 'Female'];

  void selectImage() async {
    Uint8List? im = await pickImage(ImageSource.gallery);
    setState(() => _image = im);
  }

  void completeProfile() async {
    if (_selectedRegion == null || _selectedGender == null) {
      showSnackBar(context, 'Please fill all fields');
      return;
    }

    // Trim and validate username
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      showSnackBar(context, 'Please enter a username');
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      showSnackBar(context,
          'Invalid username. Use lowercase, numbers, and underscores only.');
      return;
    }

    setState(() => _isLoading = true);

    String res = await AuthMethods().completeProfile(
      username: username, // Use processed username
      bio: _bioController.text,
      file: _image,
      isPrivate: _isPrivate,
      region: _selectedRegion!,
      age: widget.age,
      gender: _selectedGender!,
    );

    if (res == "success") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ResponsiveLayout(
            mobileScreenLayout: MobileScreenLayout(),
            webScreenLayout: WebScreenLayout(),
          ),
        ),
      );
    } else {
      showSnackBar(context, res);
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _deleteUnverifiedUserIfIncomplete();
    super.dispose();
  }

  Future<void> _deleteUnverifiedUserIfIncomplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Profile Setup',
                  style: TextStyle(
                    color: Color(0xFFd9d9d9),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Stack(
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF333333),
                      ),
                      child: _image != null
                          ? ClipOval(
                              child: Image.memory(
                                _image!,
                                fit: BoxFit.cover,
                                width: 150,
                                height: 150,
                              ),
                            )
                          : const Icon(
                              Icons.account_circle,
                              size: 150,
                              color: Color(0xFF444444),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: selectImage,
                          icon: const Icon(Icons.add_a_photo,
                              color: Color(0xFFd9d9d9)),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 40),
                TextFieldInput(
                  hintText: 'Username',
                  textInputType: TextInputType.text,
                  textEditingController: _usernameController,
                  fillColor: const Color(0xFF333333),
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontFamily: 'Inter',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[a-z0-9_]*$')),
                    LowerCaseTextFormatter(),
                  ],
                ),
                const SizedBox(height: 24),
                TextFieldInput(
                  hintText: 'Bio',
                  textInputType: TextInputType.text,
                  textEditingController: _bioController,
                  fillColor: const Color(0xFF333333),
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF333333),
                      value: _selectedRegion,
                      decoration: const InputDecoration(
                        labelText: 'Region/Country',
                        labelStyle: TextStyle(color: Color(0xFFd9d9d9)),
                        border: InputBorder.none,
                      ),
                      items: _regions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: Color(0xFFd9d9d9),
                              fontFamily: 'Inter',
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedRegion = value),
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Color(0xFFd9d9d9)),
                      style: const TextStyle(
                        color: Color(0xFFd9d9d9),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF333333),
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        labelStyle: TextStyle(color: Color(0xFFd9d9d9)),
                        border: InputBorder.none,
                      ),
                      items: _genders.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: Color(0xFFd9d9d9),
                              fontFamily: 'Inter',
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedGender = value),
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Color(0xFFd9d9d9)),
                      style: const TextStyle(
                        color: Color(0xFFd9d9d9),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Private Account',
                      style: TextStyle(
                        color: Color(0xFFd9d9d9),
                        fontFamily: 'Inter',
                      ),
                    ),
                    value: _isPrivate,
                    activeColor: const Color(0xFFd9d9d9),
                    onChanged: (value) => setState(() => _isPrivate = value),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333333),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _isLoading ? null : completeProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'Complete Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
