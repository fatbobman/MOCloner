//
//  File.swift
//
//
//  Created by Yang Xu on 2021/11/14
//  Copyright © 2021 Yang Xu. All rights reserved.
//
//  Follow me on Twitter: @fatbobman
//  My Blog: https://www.fatbobman.com
//  微信公共号: 肘子的Swift记事本
//

@testable import MOCloner
import XCTest

extension MOClonerTests {
    var container: NSPersistentContainer {
        guard let url = Bundle.module.url(forResource: "Model", withExtension: "momd"),
              let managedObjectModel = NSManagedObjectModel(contentsOf: url)
        else {
            fatalError("Failed to load momd file")
        }

        let container = NSPersistentContainer(name: "Model", managedObjectModel: managedObjectModel)
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error {
                fatalError("Failed to load Model, error:\(error.localizedDescription)")
            }
        })

        container.viewContext.name = "testContext"
        return container
    }

    var cloner: MOCloner {
        MOCloner()
    }

    func newNote(context: NSManagedObjectContext) -> Note {
        let note = Note(context: context)
        note.createDate = Date()
        note.id = UUID()
        note.name = "note"
        note.data = String("hello world").data(using: .utf8)
        note.transient = true
        note.derived = 10
        context.saveWhenChanged()
        return note
    }

    func notesCount(context:NSManagedObjectContext) -> Int{
        var count = 0
        context.performAndWait {
            let request = NSFetchRequest<NSNumber>(entityName: Note.name)
            request.resultType = .countResultType
            let result = try! context.fetch(request).first!
            count = result.intValue
        }
        return count
    }

    func itemsCount(context:NSManagedObjectContext) -> Int {
        var count = 0
        context.performAndWait {
            let request = NSFetchRequest<NSNumber>(entityName: Item.name)
            request.resultType = .countResultType
            let result = try! context.fetch(request).first!
            count = result.intValue
        }
        return count
    }
}

extension NSManagedObjectContext {
    func saveWhenChanged() {
        if hasChanges {
            do {
                try save()
            } catch {
                print(error)
                fatalError()
            }
        }
    }
}
