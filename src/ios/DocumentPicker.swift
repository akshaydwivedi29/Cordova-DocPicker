import MobileCoreServices
enum DocumentTypes: String {
    case pdf
    case image
    case all
    case gif
    case video
    case audio

    var uti: String {
        switch self {
            case .pdf: return "com.adobe.pdf"
            case .image: return "public.image"
            case .all: return "public.data"
            case .gif: return "com.compuserve.gif"
            case .video: return "public.movie"
            case .audio: return "public.audio"
        }
    }
}

@objc(DocumentPicker)
class DocumentPicker : CDVPlugin {
    var commandCallback: String?

    @objc(getFile:)
    func getFile(command: CDVInvokedUrlCommand) {

        DispatchQueue.global(qos: .background).async {
            var arguments: [DocumentTypes] = []

            command.arguments.forEach {
                if let key =  $0 as? String, let type = DocumentTypes(rawValue: key) {
                    arguments.append(type)
                } else if let array = $0 as? [String] {
                    arguments = array.compactMap { DocumentTypes(rawValue: $0) }
                }
            }

            if arguments.isEmpty {
                self.sendError("Didn't receive any argument.")
            } else {
                self.commandCallback = command.callbackId
                self.callPicker(withTypes: arguments)
            }
        }
    }

    func callPicker(withTypes documentTypes: [DocumentTypes]) {

        let utis = documentTypes.map { $0.uti }

        DispatchQueue.main.async {

            let picker = UIDocumentPickerViewController(documentTypes: utis, in: .import)
            picker.delegate = self

            self.viewController.present(picker, animated: true, completion: nil)
        }
    }

    func documentWasSelected(document: URL) {
        var fileData: Data
        let fileName = document.lastPathComponent
        let mimeType = mimeTypeForPath(path: document.absoluteString)
        var isImage: Bool = false
        var fileSizeinBytes = 0 // get the file size in bytes
        if mimeType.lowercased().range(of:"image") != nil {
            isImage = true
        }
        do{
            fileData =  try Data(contentsOf: document)
            fileSizeinBytes = fileData.count
            self.sendResult(CDVPluginResult.init(status: CDVCommandStatus_OK, messageAs:["data:"+mimeType+";base64,"+fileData.base64EncodedString(),fileName,mimeType,isImage,fileSizeinBytes]))
            self.commandCallback = nil
        }
        catch
        {
            sendError("error reading file content")
        }
        
    }

    func sendError(_ message: String) {
        sendResult(.init(status: CDVCommandStatus_ERROR, messageAs: message))
    }

}

private extension DocumentPicker {
    func sendResult(_ result: CDVPluginResult) {

        self.commandDelegate.send(
            result,
            callbackId: commandCallback
        )
    }
}
func mimeTypeForPath(path: String) -> String {
    let url = NSURL(fileURLWithPath: path)
    let pathExtension = url.pathExtension
    
    if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
        if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
            return mimetype as String
        }
    }
    return "application/octet-stream"
}
extension DocumentPicker: UIDocumentPickerDelegate {

    @available(iOS 11.0, *)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            documentWasSelected(document: url)
        }
    }


    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL){
        documentWasSelected(document: url)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        sendError("User canceled.")
    }
}
