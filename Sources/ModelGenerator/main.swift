// .modeldef files have the following structure
//
// Initially define the class name and a description
// #@ app:              <App name>
// #@ name:             <Entity name>
// #@ description:      <Description>
// #@ loadSequence:     <Load sequence>
//
// You can include some optional directives to modify the code generated from the defaults below
// #@ access:           public
// #@ imports:          SwiftUI, CoreData
// #@ moSuffix:         MO
// #@ moSuperclass:     NSManagedObject
// #@ moConformances:   ManagedObject
// #@ vmSuffix:
// #@ vmSuperclass:     ViewModel
// #@ vmConformances:   ViewModelProtocol
//
// Next include an Attribute header followed by values for each attribute in the form
// AttributeName, Type,    ViewModel,   Optional,    Id,    InitialValue,    IncludeInit, BeforeInsert,    Lookup,    EnumName,    EnumValue1,   EnumValue2,   ...
// <Name1>,       <Type1>, ViewModel1,   <Optional1>, <Id1>, <InitialValue1>, <InInit1>,   <BeforeInsert1>, <Lookup1>, <EnumName1>, <EnumValue1>, <EnumValue2>, ...
// <Name2>,       <Type2>, ViewModel2,  <Optional2>, <Id2>, <InitialValue2>, <InInit2>,   <BeforeInsert2>,

import Foundation
import CoreData


// Build the manifest
func extractEntityName(from fileURL: URL) throws -> String {
    let content = try String(contentsOf: fileURL, encoding: .utf8)
        .replacingOccurrences(of: "\u{FEFF}", with: "")
    
    for rawLine in content.components(separatedBy: .newlines) {
        let trimmed = rawLine
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
            .trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("#@") {
            let directive = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            let parts = directive.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if parts.count == 2,
               let key = parts.first?.lowercased(),
               key == "name",
               let value = parts.last,
               !value.isEmpty {
                return value
            }
        }
    }
    
    // Fallback if `#@ name:` wasn't specified in the file
    return fileURL.deletingPathExtension().lastPathComponent
}

func uncapitalised(_ string: String) -> String {
    guard let first = string.first else { return string }
    return first.lowercased() + string.dropFirst()
}

let rawArgs = Array(CommandLine.arguments.dropFirst())

if rawArgs.first == "--manifest" {
    let manifestArgs = Array(rawArgs.dropFirst())
    guard let outputPath = manifestArgs.first else {
        fputs("Error: --manifest requires an output path\n", stderr)
        exit(1)
    }

    let inputPaths = Array(manifestArgs.dropFirst())

    do {
        let entityNames = try inputPaths.map { path -> String in
            try extractEntityName(from: URL(fileURLWithPath: path))
        }

        let listEntries = entityNames
            .map { "        \(uncapitalised($0))Entity" }
            .joined(separator: ",\n")

        let manifestCode = """
        // AUTO-GENERATED MANIFEST - DO NOT EDIT
        import Foundation

        
        enum GeneratedModels {
            static let allEntities: [Entity] = [
        \(listEntries)
            ]
        }
        """

        try manifestCode.write(
            to: URL(fileURLWithPath: outputPath),
            atomically: true,
            encoding: .utf8
        )
        exit(0)
    } catch {
        fputs("Manifest CodeGen Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

// Validate command-line arguments passed by the build plugin
let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 2, let inputPath = args.first, let outputPath = args.last else {
    fputs("Error: Expected <input-csv-path> and <output-swift-path>\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)

struct GeneratorConfig {
    var appName: String = ""
    var name: String = ""
    var description: String? = nil
    var loadSequence: Int = 0
    var accessLevel: String = "internal"
    var imports: [String] = ["SwiftUI", "CoreData"]
    var moSuffix: String = "MO"
    var moSuperclass: String = "NSManagedObject"
    var moConformances: [String] = ["ManagedObject"]
    var vmSuffix: String = ""
    var vmSuperclass: String = "ViewModel"
    var vmConformances: [String] = ["DataStoreProtocol"]
}

enum BeforeInsertEnum {
    case unique
    case nonBlank
    case any
}

enum InInitEnum {
    case yes
    case no
    case optional
}

enum TypeEnum {
    case int
    case string
    case boolean
    case date
    case float
    case uuid
    case viewModel
    case int16Enum
    case notSupported
    
    init(from value: String) {
        self = switch value.lowercased() {
        case "int":
                .int
        case "string":
                .string
        case "boolean":
                .boolean
        case "date":
                .date
        case "float":
                .float
        case "uuid":
                .uuid
        case "viewmodel":
                .viewModel
        case "int16enum":
                .int16Enum
        default:
                .notSupported
        }
    }
    
    var nsAttributeType: String {
        switch self {
        case .int:
            ".integer16AttributeType"
        case .string:
            ".stringAttributeType"
        case .boolean:
            ".booleanAttributeType"
        case .date:
            ".dateAttributeType"
        case .float:
            ".floatAttributeType"
        case .uuid:
            ".UUIDAttributeType"
        case .viewModel:
            ".UUIDAttributeType"
        case .int16Enum:
            ".integer16AttributeType"
        default:
            ".undefinedAttributeType"
        }
    }
    
    var suffix: String {
        switch self {
        case .int, .int16Enum:
            "16"
        case .viewModel:
            "Id"
        default:
            ""
        }
    }
    
    var moTypeString: String {
        switch self {
        case .int:
            "Int16"
        case .string:
            "String"
        case .boolean:
            "Bool"
        case .date:
            "Date"
        case .float:
            "Float"
        case .uuid:
            "UUID"
        case .viewModel:
            "UUID"
        case .int16Enum:
            "Int16"
        default:
            "Int16"
        }
    }
    
    var vmTypeString: String {
        switch self {
        case .int:
            "Int"
        case .string:
            "String"
        case .boolean:
            "Bool"
        case .date:
            "Date"
        case .float:
            "Float"
        case .uuid:
            "UUID"
        case .viewModel:
            ""
        case .int16Enum:
            ""
        default:
            "Int"
        }
    }
    
    func valueString(_ value: String) -> String {
        switch self {
        case .date:
            "Utility.dateString(\(value))"
        case .uuid:
            "\(value).uuidString"
        case .viewModel:
            "\(value).id.uuidString"
        default:
            value
        }
    }
    
    var initialValue: String {
        switch self {
        case .int:
            "0"
        case .string:
            "\"\""
        case .boolean:
            "false"
        case .date:
            "Date(timeIntervalSinceReferenceDate: 0)"
        case .float:
            "0.0"
        case .uuid:
            "UUID()"
        case .viewModel:
            "nullUUID"
        case .int16Enum:
            "0"
        default:
            "0"
        }
    }
}

struct AttributeDefinition {
    var name: String = ""
    var desc: String = ""
    var type: TypeEnum = .notSupported
    var viewModel: String = ""
    var optional: Bool = false
    var initValue: String = ""
    var inInit: InInitEnum = .no
    var id: Bool = false
    var beforeInsert: BeforeInsertEnum = .any
    var lookup: Bool = false
    var enumName: String? = nil
    var enumValues: [Int:String] = [:]
    var viewModelEntity: String? = nil
    
    func customType(vmSuffix: String) -> String {
        switch type {
        case .viewModel: ((viewModelEntity ?? "Unspecified") + vmSuffix)
        case .int16Enum: enumName ?? "Unspecified"
        default: type.vmTypeString
        }
    }
}

do {
    let csvContent = try String(contentsOf: inputURL, encoding: .utf8)
    let rawLines = csvContent.components(separatedBy: .newlines)
    
    var config = GeneratorConfig()
    var dataRows: [(lineNumber: Int, content: String)] = []
    
    // Separate '#@' configuration directives from CSV data rows
    for (index, rawLine) in rawLines.enumerated() {
        let lineNumber = index + 1
        let trimmed = rawLine
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
            .trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty { continue }
        
        if trimmed.hasPrefix("#@") {
            let directive = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            let parts = directive.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            
            guard parts.count == 2, let rawKey = parts.first, let value = parts.last else {
                fputs("\(inputURL.path()):\(lineNumber): error: Invalid config format. Expected '#@ key: value'\n", stderr)
                exit(1)
            }
            
            let key = rawKey.lowercased()
            
            switch key.lowercased() {
            case "appname":
                config.appName = value
            case "name":
                config.name = value
            case "description":
                config.description = value
            case "loadsequence":
                config.loadSequence = Int(value) ?? 0
            case "access":
                config.accessLevel = value
            case "imports":
                config.imports = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            case "mosuffix":
                config.moSuffix = value
            case "mosuperclass":
                config.moSuperclass = value
            case "moconformances":
                config.moConformances = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            case "vmsuffix":
                config.vmSuffix = value
            case "vmsuperclass":
                config.vmSuperclass = value
            case "vmconformances":
                config.vmConformances = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            default:
                fputs("\(inputURL.path()):\(lineNumber): warning: Unknown config key '\(key)'\n", stderr)
            }
        } else if trimmed.hasPrefix("#") {
            continue
        } else {
            dataRows.append((lineNumber, rawLine.trimmingCharacters(in: .whitespaces)))
        }
    }
    
    guard dataRows.count >= 2 else {
        fputs("\(inputURL.path()):Header: error: CSV file must contain a header row and at least one data row\n", stderr)
        exit(1)
    }
    
    // Parse CSV data rows (skipping the header row at index 0)
    var attributes: [AttributeDefinition] = []
    
    let headerColumns = dataRows.first!.content.components(separatedBy: ",").map {
        $0.trimmingCharacters(in: .whitespaces).lowercased()
    }
    
    guard headerColumns.contains("name") && headerColumns.contains("type") else {
        fputs("\(inputURL.path()):Header: error: Attribute name column and type column not defined\n", stderr)
        exit(1)
    }
    
    for (rowIndex, row) in dataRows.dropFirst().enumerated() {
        let columns = row.content.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        
        if !columns.isEmpty {
            var attribute = AttributeDefinition()
            
            for (index, value) in columns.enumerated() {
                if index < headerColumns.count {
                    let columnName = headerColumns[index]
                    switch columnName {
                    case "name":
                        attribute.name = value
                    case "desc":
                        attribute.desc = value
                    case "type":
                        attribute.type = TypeEnum(from: value)
                    case "optional":
                        attribute.optional = (value.lowercased() == "true")
                    case "initvalue":
                        attribute.initValue = value
                    case "ininit":
                        attribute.inInit = (value.lowercased() == "yes" || value.lowercased() == "true" ? .yes : (value.lowercased() == "optional" ? .optional : .no))
                    case "id":
                        attribute.id = (value.lowercased() == "true")
                    case "beforeinsert":
                        let lower = value.lowercased()
                        attribute.beforeInsert = (lower == "unique" ? .unique : (lower == "nonblank" ? .nonBlank : .any))
                    case "lookup":
                        attribute.lookup = (value.lowercased() == "true")
                    case "viewmodelentity":
                        attribute.viewModelEntity = value
                    case "enumname":
                        attribute.enumName = value
                    default:
                        if columnName.prefix(9) == "enumvalue" && columnName.count > 9 {
                            if let occurrence = Int(columnName.suffix(columnName.count - 9)) {
                                attribute.enumValues[occurrence] = value
                            }
                        }
                    }
                }
            }
            guard attribute.name != "" else {
                fputs("\(inputURL.path()):Attribute \(rowIndex): error: Attribute name not defined", stderr)
                exit(1)
            }
            guard attribute.type != .notSupported else {
                fputs("\(inputURL.path()):Attribute \(rowIndex): error: Attribute type not supported", stderr)
                exit(1)
            }
            attributes.append(attribute)
        }
        guard !attributes.isEmpty else {
            fputs("\(inputURL.path()):Attributes: error: No attributes defined", stderr)
            exit(1)
        }
        
    }
    
    // Generate the Swift source code
    var outputLines: [String] = [
        "// AUTO-GENERATED FROM \(inputURL.lastPathComponent) - DO NOT EDIT",
        ""
    ]
    
    let uncapitalisedName = uncapitalised(config.name)
    
    // MARK: - Preamble
    
    for module in config.imports {
        outputLines.append("import \(module)")
    }
    outputLines.append("")
    
    // MARK: - Entity code
    
    outputLines.append("// MARK: - \(config.description ?? config.name) Entity")
    outputLines.append("")
    outputLines.append("let \(uncapitalisedName)Entity = Entity( \"\(config.name)\", \(config.name)\(config.moSuffix).self,  \(config.name)\(config.vmSuffix).self, \(config.loadSequence), ")
    for (index, attribute) in attributes.enumerated() {
        var additional = ""
        if attribute.optional {
            additional += ", isOptional: true"
        }
        switch attribute.type {
        case .int, .int16Enum:
            additional += ", equivalent: \"\(attribute.name)\", equivalentType: .\(attribute.type)"
        default:
            break
        }
        outputLines.append("        Attribute(\"\(attribute.name)\(attribute.type.suffix)\", \(attribute.type.nsAttributeType)\(additional))\(index == attributes.count - 1 ? ")" : ",")")
    }
    outputLines.append("")
    
    let memberAccess = (config.accessLevel == "open") ? "public" : config.accessLevel
    
    // MARK: - Managed Object
    
    outputLines.append("// MARK: - \(config.description ?? config.name) Managed Object")
    outputLines.append("")
    outputLines.append("@objc \(config.accessLevel) class \(config.name)\(config.moSuffix): \(config.moSuperclass)\(config.moConformances.isEmpty ? "" : ", " + config.moConformances.joined(separator: ", ")) {")
    
    outputLines.append("    \(memberAccess) static let entity = \(uncapitalisedName)Entity")
    
    for attribute in attributes {
        
        let optionalSuffix = attribute.optional ? "?" : ""
        let idLogic = (attribute.id && attribute.type == .uuid && !attribute.optional ? "      ; \(memberAccess) var id: UUID { \(attribute.name)\(attribute.type.suffix) }" : "")
        
        var additionalDeclaration = ""
        switch attribute.type {
        case .int:
            additionalDeclaration = "     ; @IntProperty(\\\(config.name)\(config.moSuffix).\(attribute.name)\(attribute.type.suffix)) @objc \(memberAccess) var \(attribute.name): Int"
        case .int16Enum:
            additionalDeclaration = "     ; @EnumProperty(\\\(config.name)\(config.moSuffix).\(attribute.name)\(attribute.type.suffix)) @objc \(memberAccess) var \(attribute.name): \(attribute.enumName ?? "Unspecified")"
        default:
            break
        }
        
        outputLines.append("    @NSManaged \(memberAccess) var \(attribute.name)\(attribute.type.suffix): \(attribute.type.moTypeString)\(optionalSuffix) \(idLogic) \(additionalDeclaration)")
    }
    outputLines.append("")
    
    outputLines.append("    convenience init() {")
    outputLines.append("        self.init(context: CoreData.context)")
    outputLines.append("    }")
    
    for attribute in attributes {
        if attribute.type == .viewModel, let viewModelEntity = attribute.viewModelEntity {
            outputLines.append("")
            outputLines.append("    \(memberAccess) var \(attribute.name): \(viewModelEntity)\(config.vmSuffix)? {")
            outputLines.append("        get { \(viewModelEntity)\(config.vmSuffix).\(attribute.name)(id: \(attribute.name)\(attribute.type.suffix)) }")
            outputLines.append("        set { \(attribute.name)\(attribute.type.suffix) = newValue?.\(attribute.name)\(attribute.type.suffix) }")
            outputLines.append("    }")
        }
    }
    
    outputLines.append("}")
    outputLines.append("")
    
    // MARK: - View Model
    
    outputLines.append("// MARK: - \(config.description ?? config.name) View Model")
    outputLines.append("")
    outputLines.append("@Observable \(memberAccess) class \(config.name)\(config.vmSuffix): \(config.vmSuperclass)\(config.vmConformances.isEmpty ? "" : ", " + config.vmConformances.joined(separator: ", ")), Equatable {")
    
    for attribute in attributes {
        
        let initialValue = setInitialValue(attribute: attribute)
        let idLogic = (attribute.id && attribute.type == .uuid && !attribute.optional ? "                     ; \(memberAccess) override var id: UUID { \(attribute.name)\(attribute.type.suffix) }" : "")
        
        outputLines.append("    \(memberAccess) var \(attribute.name): \(attribute.customType(vmSuffix: config.vmSuffix))\(initialValue) \(idLogic)")
    }
    outputLines.append("")
    
    // MARK: - Other properties
    
    outputLines.append("    \(memberAccess) static var masterData: [\(config.name)\(config.vmSuffix)] = []")
    outputLines.append("    \(memberAccess) let itemProvider = NSItemProvider(contentsOf: URL(string: \"com.sheareronline.\(config.appName.lowercased()).\(config.name.lowercased())\")!)!")
    outputLines.append("")
    
    // MARK: - Initialisers
    
    outputLines.append("    override \(memberAccess) init() {")
    if config.vmSuperclass != "" {
        outputLines.append("        super.init()")
    }
    outputLines.append("        self.entity = \(uncapitalisedName)Entity")
    outputLines.append("    }")
    outputLines.append("")
    
    outputLines.append("    \(memberAccess) convenience init(\(uncapitalisedName)\(config.moSuffix): \(config.name)\(config.moSuffix)) {")
    outputLines.append("        self.init()")
    outputLines.append("        self.managedObject = \(uncapitalisedName)\(config.moSuffix)")
    outputLines.append("        self.revert()")
    outputLines.append("    }")
    outputLines.append("")
    
    let inInitList = attributes.map({$0.inInit})
    if inInitList.contains(.yes) || inInitList.contains(.optional)  {
        var parameters = ""
        for attribute in attributes {
            if attribute.inInit != .no {
                if parameters != "" {
                    parameters.append(", ")
                }
                var optionalAssign = ""
                if attribute.inInit == .optional {
                    optionalAssign = setInitialValue(attribute: attribute)
                }
                parameters.append("\(attribute.name): \(attribute.customType(vmSuffix: config.vmSuffix))\(optionalAssign)")
            }
        }
        outputLines.append("    \(memberAccess) convenience init(\(parameters)) {")
        outputLines.append("        self.init()")
        for attribute in attributes {
            if attribute.inInit != .no {
                outputLines.append("        self.\(attribute.name) = \(attribute.name)")
            }
        }
        outputLines.append("    }")
        outputLines.append("")
    }
    
    // MARK: - Miscellaneous variables / functions
    
    outputLines.append("    \(memberAccess) override var newManagedObject: NSManagedObject { \(config.name)\(config.moSuffix)() }")
    outputLines.append("")
    
    outputLines.append("    \(memberAccess) static func == (lhs: \(config.name)\(config.vmSuffix), rhs: \(config.name)\(config.vmSuffix)) -> Bool {")
    outputLines.append("        return lhs.id == rhs.id")
    outputLines.append("    }")
    outputLines.append("")
    
    outputLines.append("    \(memberAccess) override func beforeInsert() {")
    for attribute in attributes {
        switch attribute.beforeInsert {
        case .unique:
            let exists = "\(config.name)\(config.vmSuffix).masterData.contains(where: {$0.\(attribute.name) == \(attribute.name) && $0 != self})"
            outputLines.append("        assert(!\(exists), \"\(attribute.desc) must be unique\")")
        case .nonBlank:
            outputLines.append("        assert(\(attribute.optional ? "\(attribute.name) != nil && " : "")\(attribute.name) != \(attribute.type.initialValue), \"\(attribute.desc) must be non-blank\")")
        case .any:
            break
        }
    }
    outputLines.append("    }")
    outputLines.append("")
    
    outputLines.append(    "    \(memberAccess) override var exists: Bool {")
    outputLines.append(    "        return \(config.name)\(config.vmSuffix).masterData.contains(where: {$0.id == id})")
    outputLines.append(    "    }")
    outputLines.append("")
    
    for attribute in attributes {
        if attribute.lookup {
            let parameter = (attribute.id ? "id" : attribute.name)
            outputLines.append(    "    \(memberAccess) static func \(uncapitalisedName)(\(parameter): \(attribute.type.moTypeString)?) -> \(config.name)\(config.vmSuffix)? {")
            outputLines.append(    "        return (\(parameter) == nil ? nil : \(config.name)\(config.vmSuffix).masterData.first(where: {$0.\(attribute.name) == \(parameter)}))")
            outputLines.append(    "    }")
            outputLines.append("")
        }
    }
    
    // MARK: - Key-Value overrides
    
    outputLines.append("    override \(memberAccess) func value(forKey key: String) -> Any? {")
    outputLines.append("        switch key {")
    for attribute in attributes {
        outputLines.append("            case \"\(attribute.name)\": self.\(attribute.name) as Any")
    }
    outputLines.append("            default: fatalError(\"Unknown property '\\(key)'\")")
    outputLines.append("        }")
    outputLines.append("    }")
    outputLines.append("")
    
    outputLines.append("    override \(memberAccess) func setValue(_ value: Any?, forKey key: String) {")
    outputLines.append("        switch key {")
    for attribute in attributes {
        outputLines.append("            case \"\(attribute.name)\": self.\(attribute.name) = value as\(attribute.optional ? "?" : "!") \(attribute.customType(vmSuffix: config.vmSuffix))")
    }
    outputLines.append("            default: fatalError(\"Unknown property '\\(key)'\")")
    outputLines.append("        }")
    outputLines.append("    }")
    outputLines.append("")
    
    // MARK: - Data load
    
    outputLines.append("    override class \(memberAccess) func loadData(createDefaultData: Bool) {")
    outputLines.append("        let \(uncapitalisedName)\(config.moSuffix)s = CoreData.fetch(from: \(uncapitalisedName)Entity.name) as! [\(config.name)\(config.moSuffix)]")
    outputLines.append("        Self.masterData = []")
    outputLines.append("        for \(uncapitalisedName)\(config.moSuffix) in \(uncapitalisedName)\(config.moSuffix)s {")
    outputLines.append("            Self.masterData.append(\(config.name)\(config.vmSuffix)(\(uncapitalisedName)\(config.moSuffix): \(uncapitalisedName)\(config.moSuffix)))")
    outputLines.append("        }")
    outputLines.append("        if Self.masterData.isEmpty && createDefaultData {")
    outputLines.append("            Self.createDefaultData()")
    outputLines.append("        }")
    outputLines.append("    }")
    outputLines.append("")
    
    // MARK: - Descriptions
    
    outputLines.append("    override \(memberAccess) var description: String {")
    var description = ""
    for attribute in attributes {
        if description != "" {
            description += " "
        }
        description += "\(upperFirst(attribute.name)): <\\("
        if attribute.optional {
            description += "\(attribute.name) == nil ? \"\" : "
        }
        description += "\(attribute.type.valueString(attribute.name + (attribute.optional ? "!" : ""))))>"
    }
    outputLines.append("        \"\(description)\"")
    outputLines.append("    }")
    outputLines.append("")
    
    outputLines.append("    override public var debugDescription: String { self.description }")
    outputLines.append("")
    
    outputLines.append("    // Mark: Data helper routines")
    outputLines.append("")
        
    outputLines.append("    public func insert() {")
    outputLines.append("        insert(viewModel: self)")
    outputLines.append("    }")
    outputLines.append("")
    
    outputLines.append("    public func save() {")
    outputLines.append("        if self.isNew {")
    outputLines.append("            insert(viewModel: self)")
    outputLines.append("        } else {")
    outputLines.append("           save(viewModel: self)")
    outputLines.append("        }")
    outputLines.append("    }")
    outputLines.append("")
    
    outputLines.append("    public func remove() {")
    outputLines.append("        remove(viewModel: self)")
    outputLines.append("    }")
    outputLines.append("")
    
    outputLines.append("}")
    outputLines.append("")
    
    // MARK: - Enumerations
    
    for attribute in attributes {
        if attribute.type == .int16Enum && !attribute.enumValues.isEmpty {
            outputLines.append("@objc \(memberAccess) enum \(attribute.enumName ?? "Unspecified") : Int16, Int16Enum {")
            for (value, name) in attribute.enumValues {
                outputLines.append("    case \(name) = \(value)")
            }
            outputLines.append("}")
        }
    }
    
    // MARK: - Closing
    
    let finalCode = outputLines.joined(separator: "\n")
    try finalCode.write(to: outputURL, atomically: true, encoding: .utf8)
    
    func setInitialValue(attribute: AttributeDefinition) -> String {
        (attribute.initValue != "" ? " = \(attribute.initValue)" : (attribute.optional ? "? = nil" : (attribute.type == .int16Enum ? " = \(attribute.enumName ?? "Unspecified")(rawValue: 0)!" : " = \(attribute.type.initialValue)")))
    }
    
    func uncapitalised(_ string: String) -> String {
        guard let first = string.first else { return string }
        return first.lowercased() + string.dropFirst()
    }
    
    func upperFirst(_ string: String) -> String {
        guard let first = string.first else { return string }
        return first.uppercased() + string.dropFirst()
    }
} catch {
    fputs("CodeGen Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
