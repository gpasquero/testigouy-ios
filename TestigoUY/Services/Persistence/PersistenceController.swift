import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TestigoUY")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Camera CRUD

    func fetchCameras() -> [Camera] {
        let request = NSFetchRequest<CameraEntity>(entityName: "CameraEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CameraEntity.name, ascending: true)]
        do {
            let entities = try container.viewContext.fetch(request)
            return entities.map { $0.toCamera() }
        } catch {
            print("Failed to fetch cameras: \(error)")
            return []
        }
    }

    func saveCamera(_ camera: Camera) {
        let context = container.viewContext
        let request = NSFetchRequest<CameraEntity>(entityName: "CameraEntity")
        request.predicate = NSPredicate(format: "id == %@", camera.id as CVarArg)

        let entity: CameraEntity
        if let existing = try? context.fetch(request).first {
            entity = existing
        } else {
            entity = CameraEntity(context: context)
            entity.id = camera.id
        }

        entity.name = camera.name
        entity.host = camera.host
        entity.rtspPort = Int32(camera.rtspPort)
        entity.rtspPath = camera.rtspPath
        entity.username = camera.username
        entity.password = camera.password
        entity.onvifPort = Int32(camera.onvifPort)
        entity.ptzCapability = camera.ptzCapability.rawValue
        entity.streamProfile = camera.streamProfile.rawValue
        entity.isEnabled = camera.isEnabled

        saveContext()
    }

    func deleteCamera(id: UUID) {
        let context = container.viewContext
        let request = NSFetchRequest<CameraEntity>(entityName: "CameraEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let entity = try? context.fetch(request).first {
            context.delete(entity)
            saveContext()
        }
    }

    // MARK: - Recording CRUD

    func fetchRecordings(for cameraId: UUID? = nil) -> [Recording] {
        let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecordingEntity.startDate, ascending: false)]
        if let cameraId {
            request.predicate = NSPredicate(format: "camera.id == %@", cameraId as CVarArg)
        }
        do {
            let entities = try container.viewContext.fetch(request)
            return entities.map { $0.toRecording() }
        } catch {
            print("Failed to fetch recordings: \(error)")
            return []
        }
    }

    func saveRecording(_ recording: Recording) {
        let context = container.viewContext
        let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
        request.predicate = NSPredicate(format: "id == %@", recording.id as CVarArg)

        let entity: RecordingEntity
        if let existing = try? context.fetch(request).first {
            entity = existing
        } else {
            entity = RecordingEntity(context: context)
            entity.id = recording.id

            // Link to camera
            let camRequest = NSFetchRequest<CameraEntity>(entityName: "CameraEntity")
            camRequest.predicate = NSPredicate(format: "id == %@", recording.cameraId as CVarArg)
            entity.camera = try? context.fetch(camRequest).first
        }

        entity.cameraName = recording.cameraName
        entity.filePath = recording.filePath
        entity.startDate = recording.startDate
        entity.endDate = recording.endDate
        entity.fileSize = recording.fileSize
        entity.thumbnailPath = recording.thumbnailPath

        saveContext()
    }

    func deleteRecording(id: UUID) {
        let context = container.viewContext
        let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let entity = try? context.fetch(request).first {
            // Delete file from disk
            if let path = entity.filePath {
                try? FileManager.default.removeItem(atPath: path)
            }
            if let thumbPath = entity.thumbnailPath {
                try? FileManager.default.removeItem(atPath: thumbPath)
            }
            context.delete(entity)
            saveContext()
        }
    }

    private func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error)")
        }
    }
}

// MARK: - Entity Conversions

extension CameraEntity {
    func toCamera() -> Camera {
        Camera(
            id: id ?? UUID(),
            name: name ?? "",
            host: host ?? "",
            rtspPort: Int(rtspPort),
            rtspPath: rtspPath ?? "/stream1",
            username: username ?? "",
            password: password ?? "",
            onvifPort: Int(onvifPort),
            ptzCapability: PTZCapability(rawValue: ptzCapability ?? "none") ?? .none,
            streamProfile: StreamProfile(rawValue: streamProfile ?? "main") ?? .main,
            isEnabled: isEnabled
        )
    }
}

extension RecordingEntity {
    func toRecording() -> Recording {
        Recording(
            id: id ?? UUID(),
            cameraId: camera?.id ?? UUID(),
            cameraName: cameraName ?? "",
            filePath: filePath ?? "",
            startDate: startDate ?? Date(),
            endDate: endDate,
            fileSize: fileSize,
            thumbnailPath: thumbnailPath
        )
    }
}
