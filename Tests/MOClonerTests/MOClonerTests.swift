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

class MOClonerTests: XCTestCase {
    // 只拷贝一个NSMangagedObject，没有创建关系数据
    func testForSingleObject() {
        let context = container.newBackgroundContext()
        context.performAndWait {
            let note = Note(context: context)
            note.createDate = Date().addingTimeInterval(-1000)
            note.id = UUID()
            note.name = "note"
            note.data = String("hello world").data(using: .utf8)
            note.transient = true
            note.derived = 10
            context.saveWhenChanged()

            let cloneNote = try! cloner.clone(object: note) as! Note
            XCTAssertEqual(note.name, cloneNote.name)
            XCTAssertEqual(note.data, cloneNote.data)
            XCTAssertEqual(note.transient, cloneNote.transient)
            XCTAssertEqual(note.derived, cloneNote.derived)
            // rebuild:now
            XCTAssertNotEqual(note.createDate, cloneNote.createDate)
            // rebuild:uuid
            XCTAssertNotEqual(note.id, cloneNote.id)

            // count in context
            XCTAssertEqual(notesCount(context: context), 2)
        }
    }

    // Test on-to-many
    func testOneToMany() {
        let context = container.newBackgroundContext()
        context.performAndWait {
            let note = newNote(context: context)
            // make items
            var items = [Item]()
            for i in 0..<10 {
                let item = Item(context: context)
                item.note = note
                item.noteID = note.id
                item.name = "item\(i)"
                item.index = Int32(i)
                items.append(item)
            }
            context.saveWhenChanged()
            XCTAssertEqual(note.items?.count, 10)
            XCTAssertEqual(items.first?.note, note)

            // clone
            let cloneNote = try! cloner.clone(object: note) as! Note

            XCTAssertEqual(cloneNote.items?.count, 10)
            XCTAssertNotEqual(cloneNote.id, note.id)

            let cloneItems = cloneNote.items?.allObjects as! [Item]
            for cloneItem in cloneItems {
                XCTAssertEqual(cloneItem.note, cloneNote)
                // test followParent
                XCTAssertEqual(cloneItem.noteID, cloneNote.id)
            }

            // count in context
            XCTAssertEqual(notesCount(context: context), 2)
            XCTAssertEqual(itemsCount(context: context), 20)

        }
    }

    func testOneToOne() {
        let context = container.newBackgroundContext()
        context.performAndWait {
            let note = newNote(context: context)
            let noteDescription = NoteDescription(context: context)
            noteDescription.content = "description for note"
            noteDescription.note = note

            context.saveWhenChanged()

            // test
            let cloneNote = try! cloner.clone(object: note) as! Note
            let cloneNoteDescription = cloneNote.noteDescription!

            XCTAssertNotEqual(cloneNoteDescription.objectID, noteDescription.objectID)
            XCTAssertEqual(cloneNoteDescription.note, cloneNote)
        }
    }
}
