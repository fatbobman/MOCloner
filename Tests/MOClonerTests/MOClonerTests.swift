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
                item.noteIDBlank = note.id
                item.noteIDKeep = note.id
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
                XCTAssertEqual(cloneItem.noteIDBlank, cloneNote.id)
                XCTAssertEqual(cloneItem.noteIDBlank, cloneNote.id)
            }

            // count in context
            XCTAssertEqual(notesCount(context: context), 2)
            XCTAssertEqual(itemsCount(context: context), 20)
        }
    }

    // test one-to-one
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
            XCTAssertEqual(noteDescriptionsCount(context: context), 2)
            XCTAssertEqual(notesCount(context: context), 2)
        }
    }

    // test inverse relationship is one-to-many
    func testInverseRelationShipIsOneToMany() {
        let context = container.newBackgroundContext()
        context.performAndWait {
            // create note
            let note = newNote(context: context)
            // create item
            let item = Item(context: context)
            item.note = note
            item.noteIDBlank = note.id
            item.noteIDKeep = note.id
            item.index = 0
            item.name = "item1"

            // create one-to-one tag
            // inverse relationship is to-many
            let tag = ToOneTag(context: context)
            item.toOneTag = tag
            context.saveWhenChanged()

            // clone
            let cloneNote = try! cloner.clone(object: note) as! Note
            XCTAssertEqual(cloneNote.items?.count, 1)

            let cloneItem = (cloneNote.items?.allObjects as! [Item]).first!
            XCTAssertNotEqual(cloneItem.objectID, item.objectID)
            // same tag
            XCTAssertEqual(cloneItem.toOneTag, item.toOneTag)
            XCTAssertEqual(cloneItem.toOneTag, tag)

            XCTAssertEqual(itemsCount(context: context), 2)
            XCTAssertEqual(notesCount(context: context), 2)
            XCTAssertEqual(toOneTagsCount(context: context), 1)
        }
    }

    func testInverseRelationShipIsOneToMany2() {
        let context = container.newBackgroundContext()
        context.performAndWait {
            // create note
            let note = newNote(context: context)

            // create tags ToOneTag
            let tag1 = ToOneTag(context: context)
            tag1.name = "tag1"

            let tag2 = ToOneTag(context: context)
            tag2.name = "tag2"

            // create items
            var items = [Item]()

            for i in 0..<10 {
                let item = Item(context: context)
                item.note = note
                item.noteIDKeep = note.id
                item.noteIDBlank = note.id
                item.index = Int32(i)
                item.name = "\(i)"
                item.toOneTag = tag1
                items.append(item)
            }

            for i in 0..<10 {
                let item = Item(context: context)
                item.note = note
                item.noteIDKeep = note.id
                item.noteIDBlank = note.id
                item.index = Int32(i)
                item.name = "\(i + 10)"
                item.toOneTag = tag2
                items.append(item)
            }

            context.saveWhenChanged()

            XCTAssertEqual(tag1.items?.count, 10)
            XCTAssertEqual(tag2.items?.count, 10)
            XCTAssertEqual(itemsCount(context: context), 20)

            // clone

            let cloneNote = try! cloner.clone(object: note) as! Note
            let cloneitems = cloneNote.items?.allObjects as! [Item]

            XCTAssertEqual(tag1.items?.count, 20)
            XCTAssertEqual(tag2.items?.count, 20)

            for cloneitem in cloneitems {
                XCTAssertTrue([tag1, tag2].contains(cloneitem.toOneTag!))
            }
        }
    }

    // test inverse relationship is many to many
    func testInverseRelationShipIsManyToMany() {
        let context = container.newBackgroundContext()
        context.performAndWait {
            // create note
            let note = newNote(context: context)

            // create tags ToOneTag
            let tag1 = ToManyTag(context: context)
            tag1.name = "tag1"

            let tag2 = ToManyTag(context: context)
            tag2.name = "tag2"

            // create items
            var items = [Item]()

            // tag1 item
            for i in 0..<5 {
                let item = Item(context: context)
                item.note = note
                item.noteIDKeep = note.id
                item.noteIDBlank = note.id
                item.index = Int32(i)
                item.name = "\(i)"
                item.addToToManyTags(tag1)
                items.append(item)
            }

            // tag2 item
            for i in 0..<5 {
                let item = Item(context: context)
                item.note = note
                item.noteIDKeep = note.id
                item.noteIDBlank = note.id
                item.index = Int32(i)
                item.name = "\(i)"
                item.addToToManyTags(tag2)
                items.append(item)
            }

            // tag1 and tag2 item
            for i in 0..<5 {
                let item = Item(context: context)
                item.note = note
                item.noteIDKeep = note.id
                item.noteIDBlank = note.id
                item.index = Int32(i)
                item.name = "\(i)"
                item.addToToManyTags(tag2)
                item.addToToManyTags(tag1)
                items.append(item)
            }

            context.saveWhenChanged()
            XCTAssertEqual(toManyTagsCount(context: context), 2)
            XCTAssertEqual(itemsCount(context: context), 15)
            XCTAssertEqual(tag1.items?.count, 10)
            XCTAssertEqual(tag2.items?.count, 10)

            // clone
            let cloneNote = try! cloner.clone(object: note) as! Note
            XCTAssertEqual(tag1.items?.count, 20)
            XCTAssertEqual(tag2.items?.count, 20)
            let cloneItems = cloneNote.items?.allObjects as! [Item]
            var onlyTag1Count = 0
            var onlyTag2Count = 0
            var bothTagsCount = 0
            for cloneItem in cloneItems {
                let tags = cloneItem.toManyTags?.allObjects as! [ToManyTag]
                if tags.count == 1 {
                    if tags.first!.objectID == tag1.objectID {
                        onlyTag1Count += 1
                    }
                    if tags.first!.objectID == tag2.objectID {
                        onlyTag2Count += 1
                    }
                }
                if tags.count == 2 {
                    if tags.allSatisfy({[tag1,tag2].contains($0)}) {
                        bothTagsCount += 1
                    }
                }
            }

            XCTAssertEqual(onlyTag1Count, 5)
            XCTAssertEqual(onlyTag2Count, 5)
            XCTAssertEqual(bothTagsCount, 5)
        }
    }

    // test to-many ordered
    func testToManyOredered() {
        
    }
}
