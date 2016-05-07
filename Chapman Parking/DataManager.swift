//
//  DataManager.swift
//  Chapman Parking
//
//  Created by Stephen Ciauri on 5/5/16.
//  Copyright © 2016 Stephen Ciauri. All rights reserved.
//

import Foundation
import CoreData

class DataManager{
    // MARK: - Core Data stack
    
    private static var refreshTimer: NSTimer = DataManager.initRefreshTimer()
    static var autoRefreshEnabled: Bool = true{
        didSet{
            if autoRefreshEnabled{
                refreshTimer = DataManager.initRefreshTimer()
            }else{
                refreshTimer.invalidate()
            }
        }
    }
    static var autoRefreshInterval: Double = 1
    
    private class func initRefreshTimer() -> NSTimer{
        return NSTimer.scheduledTimerWithTimeInterval(autoRefreshInterval, target: DataManager.self, selector: #selector(DataManager.timerUpdateCounts), userInfo: nil, repeats: true)

    }
    
    private static var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.stephenciauri.Chapman_Parking" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()
    
    static var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("Chapman_Parking", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()
    
    
    static var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        let url = applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()
    
    static var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContext.undoManager = nil
        managedObjectContext.persistentStoreCoordinator = coordinator
        NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: nil, queue: nil, usingBlock: {note in DataManager.contextDidSaveNotificationHandler(note)})
        return managedObjectContext
    }()
    
    class func contextDidSaveNotificationHandler(notification: NSNotification){
        let sender = notification.object as! NSManagedObjectContext
        if sender !== managedObjectContext {
            managedObjectContext.performBlock {
                NSLog("Merging")
                self.managedObjectContext.mergeChangesFromContextDidSaveNotification(notification)
                saveContext()
            }
        }
    }
    
    // Creates a new Core Data stack and returns a managed object context associated with a private queue.
    private class func createPrivateQueueContext() throws -> NSManagedObjectContext {
        
        // Stack uses the same store and model, but a new persistent store coordinator and context.
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        /*
         Attempting to add a persistent store may yield an error--pass it out of
         the function for the caller to deal with.
         */
        let storeURL = applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
        try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil)
        
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        
        context.performBlockAndWait() {
            
            context.persistentStoreCoordinator = coordinator
            
            // Avoid using default merge policy in multi-threading environment:
            // when we delete (and save) a record in one context,
            // and try to save edits on the same record in the other context before merging the changes,
            // an exception will be thrown because Core Data by default uses NSErrorMergePolicy.
            // Setting a reasonable mergePolicy is a good practice to avoid that kind of exception.
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            // In OS X, a context provides an undo manager by default
            // Disable it for performance benefit
            context.undoManager = nil
        }
        
        return context
    }
    
    // MARK: - Core Data Saving support
    
    class func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
                NSLog("Saved")
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    

    enum ParkingObject{
        case Structure
        case Level
    }
    


    
    private class func parkingStructureForName(name: String, moc: NSManagedObjectContext) -> Structure?{
        let request = NSFetchRequest(entityName: "Structure")
        request.predicate = NSPredicate(format: "name == %@", name)
        do{
            return try moc.executeFetchRequest(request).first as? Structure
        }catch{
            return nil
        }
    }
    
    private class func levelInStructureWithName(structure: Structure, name: String, moc: NSManagedObjectContext) -> Level?{
        let request = NSFetchRequest(entityName: "Level")
        request.predicate = NSPredicate(format: "structure == %@ AND name == %@", structure, name)
        do{
            return try moc.executeFetchRequest(request).first as? Level
        }catch{
            return nil
        }
    }
    

    
    @objc
    class func timerUpdateCounts(){
        updateCounts(.Latest)
    }

    

    class func updateCounts(updateType: UpdateType){
//        NSRunLoop.currentRunLoop().addTimer(refreshTimer, forMode: NSRunLoopCommonModes)
        WebAPI.generateReport(updateType, withBlock: {report in
            let backgroundContext = try! createPrivateQueueContext()
            for structure in report.structures{
                var s: Structure
                
                if let structure = parkingStructureForName(structure.name!, moc: backgroundContext){
                    s = structure
                }else{
                    s = NSEntityDescription.insertNewObjectForEntityForName("Structure", inManagedObjectContext: backgroundContext) as! Structure
                    let loc = NSEntityDescription.insertNewObjectForEntityForName("Location", inManagedObjectContext: backgroundContext) as! Location
                    loc.lat = structure.lat
                    loc.long = structure.long
                }

                s.name = structure.name
                
                for level in structure.levels{
                    var l: Level
                    
                    if let level = levelInStructureWithName(s, name: level.name!, moc: backgroundContext){
                        l = level
                    }else{
                        l = NSEntityDescription.insertNewObjectForEntityForName("Level", inManagedObjectContext: backgroundContext) as! Level
                        l.structure = s
                    }
                    
                    l.name = level.name
                    l.capacity = level.capacity
                    
                    for count in level.counts{
                        let c = NSEntityDescription.insertNewObjectForEntityForName("Count", inManagedObjectContext: backgroundContext) as! Count
                        c.availableSpaces = count.count
                        c.updatedAt = count.timestamp
                        c.level = l
                    }
                }
                
            }
            try! backgroundContext.save()
        })
        
    }
}