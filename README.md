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

# Upload only files from a specific directory
./run.rkt -u -p /path/to/specific/subdirectory /path/to/source 01/04/23

# Upload only files from a specific directory to a custom server
./run.rkt -s http://custom-server.com/upload -p /path/to/specific/subdirectory /path/to/source 01/04/23

# Test the upload functionality with a specific date
./test-localhost.rkt

# Test the directory prefix filter
./test-prefix.rkt

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

;; Upload only files from a specific directory
(sync "/path/to/source" "01/04/23" #f #t "/path/to/specific/subdirectory")

;; Upload only files from a specific directory to a custom server
(sync "/path/to/source" "01/04/23" #f "http://custom-server.com/upload" "/path/to/specific/subdirectory")

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
- Filter files by directory prefix to only process files in specific directories
- Support for custom server URLs and parameters
- HTTPS support with minimal security validation (no certificate verification for maximum compatibility)

## Implementation Notes

The implementation provides a complete file upload system with the following capabilities:

1. **HTTP/HTTPS Client**: A TCP-based client implementation that handles both HTTP and HTTPS with minimal security validation (no certificate verification)
2. **Multipart Encoding**: Full support for multipart/form-data encoding for file uploads
3. **Directory Filtering**: Support for processing only files within a specified directory
4. **Modification Tracking**: Uses git history when available, falls back to file system dates
5. **Progress Tracking**: Displays upload progress with percentage indicators
6. **Custom Server Support**: Can upload to any HTTP or HTTPS server that accepts multipart/form-data uploads

### Testing Tools

The package includes several testing utilities:

- **test-localhost.rkt**: Tests all functionality against a local server
- **test-prefix.rkt**: Tests the directory prefix filtering feature
- **test-server.rkt**: A simple HTTP server implementation for testing uploads locally
