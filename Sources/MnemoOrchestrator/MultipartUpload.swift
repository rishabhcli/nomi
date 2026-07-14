import Foundation

struct MultipartUploadBody {
    let url: URL
    let byteCount: Int64

    static func make(
        fileURL: URL,
        boundary: String,
        fields: [(String, String)]
    ) throws -> MultipartUploadBody {
        let output = FileManager.default.temporaryDirectory
            .appending(path: "mnemo-multipart-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: output.path, contents: nil),
              let writer = try? FileHandle(forWritingTo: output)
        else { throw CocoaError(.fileWriteUnknown) }
        defer { try? writer.close() }

        func write(_ string: String) throws {
            guard let data = string.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            try writer.write(contentsOf: data)
        }

        try write(
            "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
            + "Content-Type: application/octet-stream\r\n\r\n"
        )
        let reader = try FileHandle(forReadingFrom: fileURL)
        defer { try? reader.close() }
        while let chunk = try reader.read(upToCount: 1_048_576), !chunk.isEmpty {
            try writer.write(contentsOf: chunk)
        }
        try write("\r\n")

        for (name, value) in fields {
            try write(
                "--\(boundary)\r\n"
                + "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
                + "\(value)\r\n"
            )
        }
        try write("--\(boundary)--\r\n")
        let size = try writer.offset()
        return MultipartUploadBody(url: output, byteCount: Int64(size))
    }
}
