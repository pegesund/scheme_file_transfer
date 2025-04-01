# Syncer

A simple directory synchronization and file upload utility written in Racket.

## Usage

### Command Line

```bash
# Check modified files since date
./run.rkt /path/to/source 01/04/23

# Copy modified files to destination
./run.rkt -d /path/to/destination /path/to/source 01/04/23

# Upload modified files to default server
./run.rkt -u /path/to/source 01/04/23

# Upload modified files to specific server
./run.rkt -s http://custom-server.com/upload /path/to/source 01/04/23

# Upload modified files to localhost test server
./run.rkt -s http://localhost:8080/uploadxml/uploadfile /path/to/source 01/04/23

# Upload only files containing a specific string in their path
./run.rkt -u -p testsub /path/to/source 01/04/23  # Only uploads files with "testsub" in the path

# Upload only files in a specific directory
./run.rkt -u -p /full/path/to/directory /path/to/source 01/04/23  # Only uploads files in the specified directory

# Upload only files with path filtering to a custom server
./run.rkt -s http://custom-server.com/upload -p testsub /path/to/source 01/04/23

# Test the upload functionality with a specific date
./test-localhost.rkt

# Test the path prefix filter (original implementation)
./test-prefix.rkt

# Test the improved path prefix filter 
./test-prefix-new.rkt

# Test HTTPS upload functionality
./test-https.rkt
```

### As a Library

```racket
(require "src/main.rkt")

;; Check modified files
(sync "/path/to/source" "01/04/23")

;; Copy to destination
(sync "/path/to/source" "01/04/23" "/path/to/destination")

;; Upload to default server
(sync "/path/to/source" "01/04/23" #f #t)

;; Upload to specific server
(sync "/path/to/source" "01/04/23" #f "http://custom-server.com/upload")

;; Upload only files containing a specific string in their path
(sync "/path/to/source" "01/04/23" #f #t "testsub")  ; Only files with "testsub" in their path

;; Upload only files in a specific directory
(sync "/path/to/source" "01/04/23" #f #t "/full/path/to/directory")  ; Only files in the specified directory

;; Upload only files with path filtering to a custom server
(sync "/path/to/source" "01/04/23" #f "http://custom-server.com/upload" "testsub")

;; Upload specific files
(upload-files (list "/path/to/file1" "/path/to/file2"))
```

## Default Server

The default server for uploading files is:
`http://prometheus.statsbiblioteket.dk/uploadxml/uploadfile`

## Request Parameters

Upload requests use the following parameters:
- `epub`: The file content (despite the name, can be any file type)
- `comment`: Comment including upload date
- `filename`: The file name

## Features

- Find files modified after a specific date using git history or file modification date
- Upload files to HTTP or HTTPS servers using multipart/form-data encoding
- Track upload progress with percentage display
- Flexible path filtering:
  - Filter by string: Only process files containing a specific string in their path
  - Filter by directory: Only process files in a specific directory
- Support for custom server URLs and parameters
- HTTPS support with minimal security validation (no certificate verification for maximum compatibility)

## Implementation Notes

The implementation provides a complete file upload system with the following capabilities:

1. **HTTP/HTTPS Client**: A TCP-based client implementation that handles both HTTP and HTTPS with minimal security validation (no certificate verification)
2. **Multipart Encoding**: Full support for multipart/form-data encoding for file uploads
3. **Flexible Path Filtering**: Support for filtering files based on path contents or directory location
4. **Modification Tracking**: Uses git history when available, falls back to file system dates
5. **Progress Tracking**: Displays upload progress with percentage indicators
6. **Custom Server Support**: Can upload to any HTTP or HTTPS server that accepts multipart/form-data uploads

### Testing Tools

The package includes several testing utilities:

- **test-localhost.rkt**: Tests all functionality against a local server
- **test-prefix.rkt**: Tests filtering files by directory path
- **test-prefix-new.rkt**: Tests filtering files by string contents in path
- **test-server.rkt**: A simple HTTP server implementation for testing uploads locally
