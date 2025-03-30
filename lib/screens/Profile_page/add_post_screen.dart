import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:helloworld/providers/user_provider.dart';
import 'package:helloworld/resources/posts_firestore_methods.dart';
import 'package:helloworld/utils/colors.dart';
import 'package:helloworld/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:helloworld/models/user.dart'; // Ensure this imports AppUser

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({Key? key}) : super(key: key);

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  Uint8List? _file;
  bool isLoading = false;
  final TextEditingController _descriptionController = TextEditingController();

  // Function to select an image
  void _selectImage(BuildContext parentContext) async {
    return showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return SimpleDialog(
          backgroundColor: Colors.grey[200],
          title: const Text(
            'Create a Post',
            style: TextStyle(color: Colors.black),
          ),
          children: <Widget>[
            SimpleDialogOption(
              padding: const EdgeInsets.all(20),
              child: const Text('Take a photo'),
              onPressed: () async {
                Navigator.pop(context);
                Uint8List? file = await pickImage(ImageSource.camera);
                if (file != null) {
                  setState(() => _file = file);
                }
              },
            ),
            SimpleDialogOption(
              padding: const EdgeInsets.all(20),
              child: const Text('Choose from Gallery'),
              onPressed: () async {
                Navigator.pop(context);
                Uint8List? file = await pickImage(ImageSource.gallery);
                if (file != null) {
                  setState(() => _file = file);
                }
              },
            ),
            SimpleDialogOption(
              padding: const EdgeInsets.all(20),
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _rotateImage() {
    if (_file == null) return;
    try {
      final image = img.decodeImage(_file!);
      if (image == null) return;
      final rotated = img.copyRotate(image, angle: 90);
      setState(() => _file = Uint8List.fromList(img.encodePng(rotated)));
    } catch (e) {
      if (context.mounted) showSnackBar(context, 'Error rotating image: $e');
    }
  }

  void postImage(AppUser user) async {
    // Changed to AppUser without model prefix
    if (user.uid.isEmpty) {
      if (context.mounted) showSnackBar(context, "User information missing");
      return;
    }

    if (_file == null) {
      if (context.mounted)
        showSnackBar(context, "Please select an image first.");
      return;
    }

    setState(() => isLoading = true);

    try {
      String res = await FireStorePostsMethods().uploadPost(
        _descriptionController.text,
        _file!,
        user.uid,
        user.username,
        user.photoUrl,
        user.region,
        user.age ?? 0,
        user.gender,
      );

      if (res == "success" && context.mounted) {
        setState(() => isLoading = false);
        showSnackBar(context, 'Posted!');
        clearImage();
        Navigator.pop(context);
      }
    } catch (err) {
      if (context.mounted) {
        setState(() => isLoading = false);
        showSnackBar(context, err.toString());
      }
    }
  }

  void clearImage() => setState(() => _file = null);

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: mobileBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            clearImage();
            Navigator.pop(context);
          },
        ),
        title: const Text('Ratedly'),
        actions: [
          TextButton(
            onPressed: () => postImage(user),
            child: const Text(
              "Post",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
          ),
        ],
      ),
      body: _file == null
          ? Center(
              child: IconButton(
                icon: const Icon(Icons.upload),
                onPressed: () => _selectImage(context),
              ),
            )
          : Column(
              children: [
                if (isLoading) const LinearProgressIndicator(),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: MemoryImage(_file!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('Edit Image'),
                        backgroundColor: Colors.grey[200],
                        children: [
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(context);
                              _rotateImage();
                            },
                            child: const Text('Rotate 90°'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('Edit Photo'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: Colors.transparent,
                        backgroundImage: (user.photoUrl != null &&
                                user.photoUrl.isNotEmpty &&
                                user.photoUrl != "default")
                            ? NetworkImage(user.photoUrl)
                            : null,
                        child: (user.photoUrl == null ||
                                user.photoUrl.isEmpty ||
                                user.photoUrl == "default")
                            ? Icon(
                                Icons.account_circle,
                                size: 42,
                                color: Colors.grey[600],
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            hintText: "Write a caption...",
                            border: InputBorder.none,
                          ),
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
