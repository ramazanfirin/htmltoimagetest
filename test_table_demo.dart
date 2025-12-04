// Test file to demonstrate HTML table rendering
// This can be used to test the HTML rendering functionality

void main() {
  // Sample HTML content with table
  String sampleHTML = '''
  ```html
  <table>
    <thead>
      <tr>
        <th>Name</th>
        <th>Age</th>
        <th>City</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>John Doe</td>
        <td>30</td>
        <td>New York</td>
      </tr>
      <tr>
        <td>Jane Smith</td>
        <td>25</td>
        <td>Los Angeles</td>
      </tr>
      <tr>
        <td>Bob Johnson</td>
        <td>35</td>
        <td>Chicago</td>
      </tr>
    </tbody>
  </table>
  ```
  ''';
  
  print("Sample HTML table content:");
  print(sampleHTML);
  print("\nThis content should now be properly detected as HTML and rendered as a table in the chat interface.");
}