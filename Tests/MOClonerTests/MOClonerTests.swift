@testable import MOCloner
import XCTest

final class MOClonerTests: XCTestCase {
    lazy var container: NSPersistentContainer = {
        guard let url = Bundle.module.url(forResource: "Model", withExtension: "momd"),
              let managedObjectModel = NSManagedObjectModel(contentsOf: url)
        else {
            fatalError("Failt to load momd file")
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
    }()

    let cloner = MOCloner()

    func testCorDataStack() {
        XCTAssertEqual(container.viewContext.name, "testContext")
    }

    /// test clone a NSManagedObject without relationship objects
    func testCloneObjectWithoutRelationship() {
        let context = container.viewContext
        context.performAndWait {
            // prepare data
            let note = Note(context: context)
            note.name = "note1"
            note.createDate = Date().addingTimeInterval(-100000)
            note.id = UUID()
            note.data = String("hello").data(using: .utf8)
            note.index = 0
            note.transient = false

            context.saveWhenChanged()
            do {
                if let cloneNote = try cloner.cloneNSMangedObject(note) as? Note {
                    XCTAssertEqual(note.data, cloneNote.data)
                    XCTAssertNotEqual(note.id, cloneNote.id)
                    XCTAssertEqual(note.name, note.name)
                    XCTAssertNotEqual(note.createDate, cloneNote.createDate)
                    XCTAssertEqual(cloneNote.derived, 0)
                    XCTAssertEqual(cloneNote.transient, false)
                } else {
                    fatalError("clone error")
                }
            } catch {
                fatalError("\(error)")
            }
        }
    }

    /// test clone a NSManagedObject with toMany relationship objects
    func testCloneObjectWithToManyObjects() {
        let context = container.viewContext
        context.performAndWait {
            let note = Note(context: context)
            note.name = "note1"
            note.createDate = Date().addingTimeInterval(-100000)
            note.id = UUID()
            note.data = String("hello").data(using: .utf8)
            note.index = 0
            note.transient = false

            let item1 = Item(context: context)
            item1.name = "item1"
            item1.note = note
            item1.index = 3

            let item2 = Item(context: context)
            item2.note = note
            item2.index = 3
            item2.name = "item2"

            context.saveWhenChanged()

            do {
                if let cloneNote = try cloner.cloneNSMangedObject(note) as? Note {
                    XCTAssertEqual(cloneNote.items?.count, 2)
                    let newItem1 = (cloneNote.items?.allObjects as? [Item])!.first(where: { $0.name == "item1" })!
                    XCTAssertEqual(note.id, newItem1.noteID)
                    XCTAssertNotEqual(newItem1.index, 3)
                } else {
                    fatalError("clone error")
                }
            } catch {
                fatalError("\(error)")
            }

            let request = NSFetchRequest<NSNumber>(entityName: Item.name)
            request.resultType = .countResultType
            let result = try! context.fetch(request).first!
            XCTAssertEqual(result, 4)
        }
    }

    /// relationship is to one ,invert relationship is to many
    func testCloneObjectWithManyToMany1() {
        let context = container.viewContext
        context.performAndWait {
            let note = Note(context: context)
            note.name = "note1"
            note.createDate = Date().addingTimeInterval(-100000)
            note.id = UUID()
            note.data = String("hello").data(using: .utf8)
            note.index = 0
            note.transient = false

            let item1 = Item(context: context)
            item1.name = "item1"
            item1.note = note
            item1.index = 3

            let item2 = Item(context: context)
            item2.note = note
            item2.index = 3
            item2.name = "item2"

            let tag1 = ToOneTag(context: context)
            tag1.name = "tag1"
            tag1.addToItems([item1, item2])

            context.saveWhenChanged()

            // check
            let cloneNote = try! cloner.cloneNSMangedObject(note) as! Note
            let newItems = cloneNote.items?.allObjects as? [Item] ?? []
            XCTAssertEqual(newItems.count, 2)
            let newItem1 = newItems.first!
            XCTAssertEqual(newItem1.toOneTag?.objectID, tag1.objectID)

            // check item count
            let request1 = NSFetchRequest<NSNumber>(entityName: Item.name)
            request1.resultType = .countResultType
            let itemCount = try! context.fetch(request1).first!
            XCTAssertEqual(itemCount, 4)

            // check tag count
            let request2 = NSFetchRequest<NSNumber>(entityName: ToOneTag.name)
            request2.resultType = .countResultType
            let tagCount = try! context.fetch(request2).first!
            XCTAssertEqual(tagCount, 1)

            let requestTag = NSFetchRequest<ToOneTag>(entityName: ToOneTag.name)
            let tag = try! context.fetch(requestTag).first!
            XCTAssertEqual(tag.items?.count, 4)
            XCTAssertEqual(tag1.items?.count, 4)
        }
    }

    /// relationship is to many ,invert relationship is to many
    func testtestCloneObjectWithManyToMany2() {
        let context = container.viewContext
        context.performAndWait {
            let note = Note(context: context)
            note.name = "note1"
            note.createDate = Date().addingTimeInterval(-100000)
            note.id = UUID()
            note.data = String("hello").data(using: .utf8)
            note.index = 0
            note.transient = false

            let item1 = Item(context: context)
            item1.name = "item1"
            item1.note = note
            item1.index = 3

            let item2 = Item(context: context)
            item2.note = note
            item2.index = 3
            item2.name = "item2"

            let tag1 = ToManyTag(context: context)
            tag1.name = "tag1"
            tag1.addToItems([item1, item2])

            let tag2 = ToManyTag(context: context)
            tag2.name = "tag2"
            tag2.addToItems(item1)

            context.saveWhenChanged()

            let cloneNote = try! cloner.cloneNSMangedObject(note) as! Note
            XCTAssertNotEqual(cloneNote.id, note.id)

            // check tag count
            let requestTagCount = NSFetchRequest<NSNumber>(entityName: ToManyTag.name)
            requestTagCount.resultType = .countResultType
            let tagCount = try! context.fetch(requestTagCount).first!
            XCTAssertEqual(tagCount, 2)

            XCTAssertEqual(tag1.items?.count, 4)
            XCTAssertEqual(tag2.items?.count, 2)
        }
    }

    func testToManyOrdered() {
        let context = container.viewContext
        context.performAndWait {
            let note = Note(context: context)
            note.name = "note1"
            note.createDate = Date().addingTimeInterval(-100000)
            note.id = UUID()
            note.data = String("hello").data(using: .utf8)
            note.index = 0
            note.transient = false

            for i in 0..<30 {
                let memo = Memo(context: context)
                memo.text = "\(i)"
                memo.note = note
            }

            context.saveWhenChanged()

            let cloneNote = try! cloner.cloneNSMangedObject(note) as! Note

            if let memos = cloneNote.memos?.array as? [Memo] {
                for i in 0..<30 {
                    XCTAssertEqual(memos[i].text, "\(i)")
                }
            }
        }
    }

    func testStrictAndExclud() {
        let context = container.viewContext
        context.performAndWait {
            let note = Note(context: context)
            note.name = "note1"
            note.createDate = Date().addingTimeInterval(-100000)
            note.id = UUID()
            note.data = String("hello").data(using: .utf8)
            note.index = 0
            note.transient = false

            let item1 = Item(context: context)
            item1.name = "item1"
            item1.note = note
            item1.index = 3

            let item2 = Item(context: context)
            item2.note = note
            item2.index = 3
            item2.name = "item2"

            context.saveWhenChanged()

            let cloneItem1 = try! cloner.cloneNSMangedObject(item1, excludedRelationshipNames: ["note"]) as! Item
            XCTAssertNil(cloneItem1.note)
            XCTAssertEqual(cloneItem1.noteID, item1.noteID)
        }
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
