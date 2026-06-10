import 'package:flutter/material.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String? _selectedGender; // 'Kız' or 'Erkek'
  DateTime? _selectedDate;
  bool _genderError = false;
  bool _dateError = false;

  // List to store multiple babies
  final List<Map<String, dynamic>> _addedBabies = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Form validator & helper to add a baby
  bool _addCurrentBabyToList() {
    setState(() {
      _genderError = _selectedGender == null;
      _dateError = _selectedDate == null;
    });

    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid || _genderError || _dateError) {
      return false;
    }

    // Add current baby to list
    final String formattedDate = _selectedDate != null 
        ? "${_selectedDate!.day.toString().padLeft(2, '0')}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.year}"
        : "";

    setState(() {
      _addedBabies.add({
        "name": _nameController.text.trim(),
        "gender": _selectedGender!,
        "dob": formattedDate,
      });

      // Clear current inputs for next baby
      _nameController.clear();
      _selectedGender = null;
      _selectedDate = null;
      _genderError = false;
      _dateError = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Bebek başarıyla eklendi! Yeni bir tane daha ekleyebilirsiniz."),
        duration: Duration(seconds: 2),
      ),
    );
    return true;
  }

  // Handle continuing to the home screen
  void _handleContinue() {
    // If the form has text or selections, try to add the current baby first
    if (_nameController.text.isNotEmpty || _selectedGender != null || _selectedDate != null) {
      final success = _addCurrentBabyToList();
      if (!success) {
        // Form had partial inputs but was invalid
        return; 
      }
    }

    // Must have at least 1 baby added or currently filled
    if (_addedBabies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen en az bir bebeğin bilgilerini doldurun veya 'Daha sonra doldurabilirsin' seçeneğini tıklayın."),
        ),
      );
      return;
    }

    // Navigate to HomeScreen with the babies list
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(initialBabies: _addedBabies),
      ),
    );
  }

  // Date picker handler
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 180)), // ~6 months old
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFB38A), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF7A7A8A), // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFB38A), // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFFB38A); // Softer Apricot
    const textColor = Color(0xFF7A7A8A); // Softer dark grey
    const lightTextColor = Color(0xFFA8A8B3);
    const borderGreyColor = Color(0xFFE2E2E6);
    const bgGreyColor = Color(0xFFF5F5F7);
    const infoBgColor = Color(0xFFFFF7F2); // Very light warm orange
    const infoTextColor = Color(0xFFE08253);

    final String formattedDateText = _selectedDate == null
        ? "Tarih Seçiniz"
        : "${_selectedDate!.day.toString().padLeft(2, '0')}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.year}";

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: textColor,
                      ),
                    ),
                  ),
                  // Steps Indicator (Orange, Grey, Grey)
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 6,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  // Empty space for layout balance
                  const SizedBox(width: 36),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      
                      // Rocket Illustration
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE2E2E6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "👶",
                              style: TextStyle(
                                fontSize: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        "Bebeğini Tanıyalım",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Beslenme yolculuğuna başlamak için\nbirkaç küçük bilgiye ihtiyacımız var.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: lightTextColor,
                          height: 1.4,
                        ),
                      ),
                      
                      const SizedBox(height: 32),

                      // Dynamic Added Babies List
                      if (_addedBabies.isNotEmpty) ...[
                        const Text(
                          "Eklenen Bebekler",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _addedBabies.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final baby = entry.value;
                            final isFemale = baby["gender"] == "Kız";
                            return Chip(
                              backgroundColor: isFemale 
                                  ? Colors.pink.withOpacity(0.08)
                                  : primaryColor.withOpacity(0.08),
                              label: Text(
                                "${baby["name"]} (${baby["gender"]})",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: isFemale ? Colors.pink[400] : infoTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              avatar: Icon(
                                isFemale ? Icons.girl : Icons.boy,
                                size: 18,
                                color: isFemale ? Colors.pink[300] : primaryColor,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              deleteIconColor: Colors.grey[500],
                              onDeleted: () {
                                setState(() {
                                  _addedBabies.removeAt(idx);
                                });
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isFemale 
                                      ? Colors.pink.withOpacity(0.15)
                                      : primaryColor.withOpacity(0.15),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Bebeğinin Adı Input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Bebeğinin Adı",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          Text(
                            "Örn: Can, Zeynep...",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: "Bebiktonun adı",
                          hintStyle: const TextStyle(
                            fontFamily: 'Inter',
                            color: lightTextColor,
                            fontSize: 15,
                          ),
                          prefixIcon: const Icon(
                            Icons.child_care_outlined,
                            color: lightTextColor,
                            size: 20,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          filled: false,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: borderGreyColor, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: primaryColor, width: 1.5),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (_addedBabies.isEmpty && (value == null || value.trim().isEmpty)) {
                            return "Bebeğinizin adını giriniz.";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Cinsiyet Selection
                      const Text(
                        "Cinsiyet",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Kız Button
                          Expanded(
                            child: _buildGenderButton(
                              gender: "Kız",
                              icon: Icons.female,
                              selectedColor: Colors.pink[300]!,
                              isSelected: _selectedGender == "Kız",
                              onTap: () {
                                setState(() {
                                  _selectedGender = "Kız";
                                  _genderError = false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Erkek Button
                          Expanded(
                            child: _buildGenderButton(
                              gender: "Erkek",
                              icon: Icons.male,
                              selectedColor: primaryColor,
                              isSelected: _selectedGender == "Erkek",
                              onTap: () {
                                setState(() {
                                  _selectedGender = "Erkek";
                                  _genderError = false;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_genderError && _addedBabies.isEmpty) ...[
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            "Lütfen cinsiyet seçiniz.",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Doğum Tarihi Girdisi
                      const Text(
                        "Doğum Tarihi",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: bgGreyColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _dateError && _addedBabies.isEmpty
                                  ? Colors.redAccent
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formattedDateText,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  color: _selectedDate == null ? lightTextColor : textColor,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_dateError && _addedBabies.isEmpty) ...[
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            "Lütfen doğum tarihini seçiniz.",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Info Box (Why do we need this info?)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: infoBgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: primaryColor.withOpacity(0.12)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: infoTextColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Neden bu bilgileri istiyoruz?",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: infoTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Ayına uygun gıda önerileri ve porsiyon takibi yapabilmek için doğum tarihi önemlidir.",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: textColor.withOpacity(0.85),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Add Another Baby Button
                      OutlinedButton.icon(
                        onPressed: _addCurrentBabyToList,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Başka Bebek Ekle"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Continue Button
                      ElevatedButton(
                        onPressed: _handleContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Devam Et",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      // Skip / Fill Later Button
                      TextButton(
                        onPressed: () {
                          // Navigate to HomeScreen with empty list
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(initialBabies: []),
                            ),
                          );
                        },
                        child: const Text(
                          "Daha sonra doldurabilirsin",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: lightTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderButton({
    required String gender,
    required IconData icon,
    required Color selectedColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const primaryColor = Color(0xFFFFB38A);
    const bgGreyColor = Color(0xFFF5F5F7);
    const borderGreyColor = Color(0xFFE2E2E6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : bgGreyColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : borderGreyColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : const Color(0xFF7A7A8A),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              gender,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? selectedColor : const Color(0xFF7A7A8A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
