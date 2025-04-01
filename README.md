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

# Test the upload functionality with a specific date
./test-localhost.rkt
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

## Implementation Notes

The current implementation uses a mock HTTP client that simulates successful uploads but doesn't actually connect to a server. This was done to avoid potential issues with TCP connection handling, timeouts, and HTTP response parsing.

For a production implementation, the following would be needed:
1. A proper HTTP client implementation with robust error handling and timeout management
2. Support for HTTPS connections with certificate verification
3. Better handling of large file uploads (possibly streaming)
4. Proper retry logic for failed uploads

The mock mode still demonstrates all the features of the API:
- Finding files modified after a specific date
- Formatting multipart form data for upload 
- Tracking upload progress with percentage display
