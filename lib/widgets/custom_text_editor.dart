import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TextEditingResult {
  final String text;
  final TextStyle style;
  final TextAlign alignment;

  TextEditingResult({
    required this.text,
    required this.style,
    required this.alignment,
  });
}

class CustomTextEditor extends StatefulWidget {
  final Function(TextEditingResult) onComplete;
  final VoidCallback onCancel;

  const CustomTextEditor({
    super.key,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<CustomTextEditor> createState() => _CustomTextEditorState();
}

class _CustomTextEditorState extends State<CustomTextEditor> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  // Toggle states
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _hasShadow = false;
  bool _hasOutline = false;
  
  TextAlign _textAlign = TextAlign.center;
  Color _textColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Build the actual TextStyle based on toggle states
  TextStyle _buildTextStyle() {
    // If outline is enabled, we must use foreground instead of color
    if (_hasOutline) {
      return TextStyle(
        fontSize: 40,
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: _isUnderline ? TextDecoration.underline : null,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _textColor,
        shadows: _hasShadow ? [
          Shadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(3, 3),
          ),
        ] : null,
      );
    }

    // Normal style with color
    return GoogleFonts.inter(
      fontSize: 40,
      color: _textColor,
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: _isUnderline ? TextDecoration.underline : null,
      shadows: _hasShadow ? [
        Shadow(
          color: Colors.black.withOpacity(0.8),
          blurRadius: 10,
          offset: const Offset(3, 3),
        ),
      ] : null,
    );
  }

  // Build hint style that matches the main style but with lower opacity
  TextStyle _buildHintStyle() {
    final hintColor = Colors.white.withOpacity(0.5);

    if (_hasOutline) {
      return TextStyle(
        fontSize: 40,
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: _isUnderline ? TextDecoration.underline : null,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = hintColor,
      );
    }

    return GoogleFonts.inter(
      fontSize: 40,
      color: hintColor,
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: _isUnderline ? TextDecoration.underline : null,
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    String? label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive 
              ? AppColors.primaryPurple.withOpacity(0.3)
              : AppColors.surface(context).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive 
                ? AppColors.primaryPurple
                : AppColors.muted(context),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive 
                  ? AppColors.primaryPurple
                  : AppColors.onBackground(context),
              size: 24,
            ),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive 
                      ? AppColors.primaryPurple
                      : AppColors.onBackground(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primaryPurple : Colors.white.withOpacity(0.3),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primaryPurple.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.onBackground(context)),
          onPressed: widget.onCancel,
        ),
        title: Text(
          'Add Text',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.onBackground(context),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: AppColors.primaryPurple),
            onPressed: () {
              if (_textController.text.isNotEmpty) {
                widget.onComplete(TextEditingResult(
                  text: _textController.text,
                  style: _buildTextStyle(),
                  alignment: _textAlign,
                ));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Text input area
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  textAlign: _textAlign,
                  maxLines: null,
                  style: _buildTextStyle(),
                  decoration: InputDecoration(
                    hintText: 'Enter text',
                    hintStyle: _buildHintStyle(),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
          
          // Controls panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Style toggles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildToggleButton(
                        icon: Icons.format_bold,
                        isActive: _isBold,
                        onTap: () => setState(() => _isBold = !_isBold),
                        label: 'Bold',
                      ),
                      _buildToggleButton(
                        icon: Icons.format_italic,
                        isActive: _isItalic,
                        onTap: () => setState(() => _isItalic = !_isItalic),
                        label: 'Italic',
                      ),
                      _buildToggleButton(
                        icon: Icons.format_underline,
                        isActive: _isUnderline,
                        onTap: () => setState(() => _isUnderline = !_isUnderline),
                        label: 'Under',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildToggleButton(
                        icon: Icons.blur_on,
                        isActive: _hasShadow,
                        onTap: () => setState(() => _hasShadow = !_hasShadow),
                        label: 'Shadow',
                      ),
                      _buildToggleButton(
                        icon: Icons.border_style,
                        isActive: _hasOutline,
                        onTap: () => setState(() => _hasOutline = !_hasOutline),
                        label: 'Outline',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Divider
                  Divider(color: AppColors.muted(context)),
                  const SizedBox(height: 16),
                  
                  // Text alignment
                  Row(
                    children: [
                      Text(
                        'Alignment',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onBackground(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.format_align_left),
                              color: _textAlign == TextAlign.left
                                  ? AppColors.primaryPurple
                                  : AppColors.onBackground(context).withOpacity(0.5),
                              onPressed: () => setState(() => _textAlign = TextAlign.left),
                            ),
                            IconButton(
                              icon: const Icon(Icons.format_align_center),
                              color: _textAlign == TextAlign.center
                                  ? AppColors.primaryPurple
                                  : AppColors.onBackground(context).withOpacity(0.5),
                              onPressed: () => setState(() => _textAlign = TextAlign.center),
                            ),
                            IconButton(
                              icon: const Icon(Icons.format_align_right),
                              color: _textAlign == TextAlign.right
                                  ? AppColors.primaryPurple
                                  : AppColors.onBackground(context).withOpacity(0.5),
                              onPressed: () => setState(() => _textAlign = TextAlign.right),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Color picker
                  Row(
                    children: [
                      Text(
                        'Color',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onBackground(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildColorButton(
                                color: Colors.white,
                                isSelected: _textColor == Colors.white,
                                onTap: () => setState(() => _textColor = Colors.white),
                              ),
                              const SizedBox(width: 12),
                              _buildColorButton(
                                color: Colors.black,
                                isSelected: _textColor == Colors.black,
                                onTap: () => setState(() => _textColor = Colors.black),
                              ),
                              const SizedBox(width: 12),
                              _buildColorButton(
                                color: Colors.red,
                                isSelected: _textColor == Colors.red,
                                onTap: () => setState(() => _textColor = Colors.red),
                              ),
                              const SizedBox(width: 12),
                              _buildColorButton(
                                color: Colors.blue,
                                isSelected: _textColor == Colors.blue,
                                onTap: () => setState(() => _textColor = Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              _buildColorButton(
                                color: Colors.green,
                                isSelected: _textColor == Colors.green,
                                onTap: () => setState(() => _textColor = Colors.green),
                              ),
                              const SizedBox(width: 12),
                              _buildColorButton(
                                color: Colors.yellow,
                                isSelected: _textColor == Colors.yellow,
                                onTap: () => setState(() => _textColor = Colors.yellow),
                              ),
                              const SizedBox(width: 12),
                              _buildColorButton(
                                color: AppColors.primaryPurple,
                                isSelected: _textColor == AppColors.primaryPurple,
                                onTap: () => setState(() => _textColor = AppColors.primaryPurple),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

