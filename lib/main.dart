import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Asistan Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const ChatPage(),
    );
  }
}

class Message {
  String type; // 'text', 'image', 'html', 'html_image'
  String content;
  bool isSent; // true for sent, false for received
  Uint8List? imageData; // For html_image type

  Message(this.type, this.content, this.isSent, {this.imageData});
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Message> messages = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    String text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(Message('text', text, true));
    });
    _controller.clear();

    try {
      String url = 'http://78.187.49.91:3030/api/ai/freeText/${Uri.encodeComponent(text)}';
      print('📤 Sending request to: $url');
      
      var response = await http.get(Uri.parse(url));

      //print('📥 Response Status Code: ${response.statusCode}');
      //print('📥 Response Headers: ${response.headers}');
      print('📥 Raw Response Body: ${response.body}');
      //print('📥 Raw Response Body Length: ${response.body.length}');
      
      if (response.statusCode == 200) {
        String resp = response.body;
        
        print('🔍 Processing response...');
        print('📊 Contains HTML: ${_containsHTML(resp)}');
        
        String type = 'text';
        Uint8List? imageData;

        // Check for HTML content with improved detection logic
        if (_containsHTML(resp)) {
          type = 'html';
          resp = _cleanHTML(resp);
          print('🧹 Cleaned HTML: $resp');
          print('🧹 Cleaned HTML Length: ${resp.length}');
        } else if (_containsMarkdownTable(resp)) {
          type = 'table';
          print('📊 Detected markdown table');
        } else if (RegExp(r'\.(jpg|jpeg|png|gif|bmp|webp)$', caseSensitive: false).hasMatch(resp)) {
          type = 'image';
          print('🖼️ Detected image URL: $resp');
        } else {
          print('📝 Detected as plain text response');
        }

        // Optionally convert HTML to image (skip for tables)
        if (type == 'html') {
          bool convertToImage = !resp.contains('<table');
          if (convertToImage) {
            print('🖼️ Converting HTML to image...');
            try {
              imageData = await _convertHtmlToImage(resp);
              type = 'html_image';
              print('✅ HTML to image conversion successful! Image size: ${imageData!.length} bytes');
            } catch (e) {
              // If conversion fails, fall back to HTML rendering
              print('❌ HTML to image conversion failed: $e');
            }
          }
        }
        
        print('📤 Final message type: $type');
        //print('📤 Message content preview: ${resp.substring(0, resp.length > 100 ? 100 : resp.length)}${resp.length > 100 ? '...' : ''}');
        
        setState(() {
          messages.add(Message(type, resp, false, imageData: imageData));
        });
      } else {
        print('❌ API Error: ${response.statusCode}');
        setState(() {
          messages.add(Message('text', 'Error: ${response.statusCode}', false));
        });
      }
    } catch (e) {
      print('💥 Exception caught: $e');
      setState(() {
        messages.add(Message('text', 'Error: $e', false));
      });
    }
  }

  bool _containsHTML(String content) {
    // Enhanced HTML detection
    return content.contains('```html') ||
           content.contains('<table') ||
           content.contains('<div>') ||
           content.contains('<p>') ||
           content.contains('<br>') ||
           content.contains('<h1>') ||
           content.contains('<h2>') ||
           content.contains('<h3>') ||
           content.contains('<h4>') ||
           content.contains('<ul>') ||
           content.contains('<ol>') ||
           content.contains('<li>') ||
           content.contains('<strong>') ||
           content.contains('<em>') ||
           content.contains('<a ') ||
           content.contains('<tr>') ||
           content.contains('<th>') ||
           content.contains('<td>') ||
           content.contains('<thead>') ||
           content.contains('<tbody>') ||
           content.contains('<tfoot>') ||
           RegExp(r'<[^>]+>', caseSensitive: false).hasMatch(content);
  }

  String _cleanHTML(String content) {
    content = content.trim();
    
    // Remove code block markers
    if (content.startsWith('```html')) {
      content = content.substring(7);
    } else if (content.startsWith('```')) {
      content = content.substring(3);
    }
    
    if (content.endsWith('```')) {
      content = content.substring(0, content.length - 3);
    }
    
    // Clean up HTML entities and whitespace
    content = content.trim();
    
    return content;
  }
  bool _containsMarkdownTable(String content) {
    List<String> lines = content.split('\n');
    int tableLines = 0;
    int totalLines = lines.length;

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('|') && line.endsWith('|') && line.split('|').length > 2) {
        tableLines++;
      } else if (line.contains('---') || line.contains('===')) {
        // Separator lines are part of table
        tableLines++;
      }
    }

    // Only treat as table if most lines are table-related (more than 70%)
    return tableLines > 0 && (tableLines / totalLines) > 0.7;
  }

  List<List<String>> _parseMarkdownTable(String content) {
    List<String> lines = content.trim().split('\n');
    List<List<String>> rows = [];
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty || line.contains('---') || line.contains('===')) continue;
      List<String> cells = line.split('|').map((s) => s.trim()).toList();
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }

  String _extractTextFromHtml(String htmlContent) {
    // Simple HTML tag removal - this is a basic implementation
    print('🔍 Starting text extraction from HTML');
    print('🔍 Original HTML content: $htmlContent');
    
    String text = htmlContent;
    
    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Decode common HTML entities
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    
    print('🔍 After tag removal and entity decoding: $text');
    
    // Remove extra whitespace
    text = text.trim();
    
    // Limit length to prevent very long images
    if (text.length > 500) {
      text = text.substring(0, 497) + '...';
      print('🔍 Text truncated to 500 characters');
    }
    
    print('🔍 Final extracted text: $text');
    print('🔍 Final text length: ${text.length}');
    
    return text;
  }

  Future<Uint8List> _convertHtmlToImage(String htmlContent) async {
    // Convert HTML text content to image
    try {
      // Extract text content from HTML
      String cleanText = _extractTextFromHtml(htmlContent);
      
      // Create a simple image with the text content
      final size = const Size(400, 300);
      
      // Create a picture recorder for canvas drawing
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      // Fill background with white
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white,
      );
      
      // Add a title
      final titlePainter = TextPainter(
        text: const TextSpan(
          text: 'HTML Content',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      titlePainter.layout(maxWidth: size.width - 32);
      titlePainter.paint(canvas, const Offset(16, 20));
      
      // Add the extracted text with wrapping
      final textPainter = TextPainter(
        text: TextSpan(
          text: cleanText,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout(maxWidth: size.width - 32);
      textPainter.paint(canvas, const Offset(16, 50));
      
      // Convert to image
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return bytes!.buffer.asUint8List();
    } catch (e) {
      print('HTML to image conversion failed: $e');
      return _createFallbackImage();
    }
  }

  Future<Uint8List> _createFallbackImage() async {
    // Create a simple fallback image
    final size = const Size(400, 300);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Fill background with white
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    
    // Add fallback text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'HTML Content\n(Conversion placeholder)',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(maxWidth: size.width - 40);
    textPainter.paint(canvas, const Offset(20, 20));
    
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Widget _getMessageWidget(Message msg) {
    switch (msg.type) {
      case 'text':
        return Text(
          msg.content,
          style: const TextStyle(color: Colors.black87),
        );
      case 'image':
        return Image.network(
          msg.content,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Text('Failed to load image');
          },
        );
      case 'html':
        return _buildHTMLWidget(msg.content);
      case 'html_image':
        return _buildHTMLImageWidget(msg.imageData);
      case 'table':
        return _buildTableWidget(msg.content);
      default:
        return Text('Unknown message type: ${msg.type}');
    }
  }

  Widget _buildHTMLWidget(String htmlContent) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 300,
          maxWidth: 600,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Html(
              data: htmlContent,
              style: {
                "html": Style(
                  backgroundColor: Colors.white,
                  color: Colors.black87,
                  fontSize: FontSize(14),
                ),
                "body": Style(
                  margin: Margins.all(0),
                  padding: HtmlPaddings.all(8),
                  fontSize: FontSize(14),
                  color: Colors.black87,
                ),
                "p": Style(
                  margin: Margins.symmetric(vertical: 4),
                  lineHeight: LineHeight(1.4),
                  color: Colors.black87,
                ),
                "table": Style(
                  border: Border.all(color: Colors.grey[400]!, width: 1.0),
                  margin: Margins.all(8),
                  backgroundColor: Colors.white,
                ),
                "thead": Style(
                  backgroundColor: Colors.grey[200]!,
                ),
                "th": Style(
                  backgroundColor: Colors.grey[200]!,
                  color: Colors.black87,
                  padding: HtmlPaddings.all(12),
                  fontWeight: FontWeight.bold,
                  border: Border.all(color: Colors.grey[400]!, width: 1.0),
                  textAlign: TextAlign.center,
                  fontSize: FontSize(16),
                ),
                "td": Style(
                  padding: HtmlPaddings.all(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1.0),
                  color: Colors.black87,
                  textAlign: TextAlign.left,
                  fontSize: FontSize(14),
                ),
                "tr:nth-child(even)": Style(
                  backgroundColor: Colors.grey[50]!,
                ),
                "h1, h2, h3, h4, h5, h6": Style(
                  color: Colors.black87,
                  margin: Margins.symmetric(vertical: 8),
                ),
                "h1": Style(fontSize: FontSize(24), fontWeight: FontWeight.bold),
                "h2": Style(fontSize: FontSize(20), fontWeight: FontWeight.bold),
                "h3": Style(fontSize: FontSize(18), fontWeight: FontWeight.w600),
                "h4": Style(fontSize: FontSize(16), fontWeight: FontWeight.w600),
                "ul, ol": Style(
                  padding: HtmlPaddings.only(left: 24),
                  margin: Margins.symmetric(vertical: 8),
                ),
                "li": Style(
                  margin: Margins.only(bottom: 4),
                  color: Colors.black87,
                ),
                "code": Style(
                  backgroundColor: Colors.grey[100]!,
                  padding: HtmlPaddings.symmetric(horizontal: 6, vertical: 2),
                  fontFamily: 'monospace',
                  fontSize: FontSize(13),
                  color: Colors.black87,
                ),
                "pre": Style(
                  backgroundColor: Colors.grey[100]!,
                  padding: HtmlPaddings.all(12),
                  margin: Margins.all(8),
                ),
                "blockquote": Style(
                  backgroundColor: Colors.grey[50]!,
                  border: Border(left: BorderSide(color: Colors.grey[400]!, width: 4)),
                  padding: HtmlPaddings.only(left: 16),
                  margin: Margins.symmetric(vertical: 8),
                  fontStyle: FontStyle.italic,
                ),
                "a": Style(
                  color: Colors.blue[600]!,
                  textDecoration: TextDecoration.underline,
                ),
                "strong": Style(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                "em": Style(
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                ),
                "span": Style(color: Colors.black87),
                "div": Style(color: Colors.black87),
                "br": Style(
                  lineHeight: LineHeight(2),
                ),
                "hr": Style(
                  border: Border(bottom: BorderSide(color: Colors.grey[400]!, width: 1.0)),
                  margin: Margins.symmetric(vertical: 8),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildTableWidget(String markdownContent) {
    List<List<String>> rows = _parseMarkdownTable(markdownContent);
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.9,
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: Colors.grey[400]!, width: 1),
              defaultColumnWidth: const FixedColumnWidth(80.0), // Fixed width per column
              children: rows.asMap().entries.map((entry) {
                int i = entry.key;
                List<String> row = entry.value;
                return TableRow(
                  children: row.map((cell) => Container(
                    constraints: const BoxConstraints(
                      maxWidth: 80.0, // Max width for text wrapping
                    ),
                    padding: const EdgeInsets.all(8),
                    color: i == 0 ? Colors.grey[200] : (i % 2 == 1 ? Colors.grey[50] : Colors.white),
                    child: Text(
                      cell,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3, // Limit lines to prevent excessive height
                    ),
                  )).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHTMLImageWidget(Uint8List? imageData) {
    if (imageData == null) {
      return const Text('Failed to convert HTML to image');
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
        maxHeight: 300,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          imageData,
          width: 300,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Text('Failed to display image');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Asistan Chat'),
        backgroundColor: Colors.deepPurple[50],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                var msg = messages[index];
                return Align(
                  alignment: msg.isSent ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isSent ? Colors.blue[200]! : Colors.grey[100]!,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: msg.isSent ? Colors.blue[300]! : Colors.grey[300]!,
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      child: _getMessageWidget(msg),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.deepPurple,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
