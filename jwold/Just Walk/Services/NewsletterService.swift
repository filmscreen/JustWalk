//
//  NewsletterService.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import CloudKit
import Combine

/// Manages newsletter subscriptions by saving emails to CloudKit Public Database.
/// This allows the developer to export the subscriber list from the iCloud Dashboard.
final class NewsletterService {
    
    static let shared = NewsletterService()
    
    private let container = CKContainer.default()
    private lazy var publicDatabase = container.publicCloudDatabase
    
    /// Saves a new subscriber to CloudKit
    func subscribe(email: String, source: String = "onboarding", ageRange: String? = nil, gender: String? = nil, weight: String? = nil) {
        let recordId = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "NewsletterSubscriber", recordID: recordId)
        
        record["email"] = email
        record["source"] = source
        record["status"] = "active"
        record["signupDate"] = Date()
        
        if let age = ageRange { record["ageRange"] = age }
        if let gen = gender { record["gender"] = gen }
        if let w = weight { record["weight"] = w }
        
        // Save to public database
        publicDatabase.save(record) { record, error in
            if let error = error {
                print("❌ Newsletter: Failed to save to CloudKit: \(error.localizedDescription)")
                // In a real app, you might want to retry or queue this for later
            } else {
                print("✅ Newsletter: Sccessfully saved \(email) to CloudKit Public DB")
            }
        }
    }
    /// Fetches all subscribers to calculate demographic stats (Admin/Dev feature)
    /// In a production app with millions of users, this should be done server-side or with simpler counters.
    func fetchAudienceStats() async throws -> AudienceBreakdown {
        let query = CKQuery(recordType: "NewsletterSubscriber", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "signupDate", ascending: false)]
        
        // We only need specific fields
        // query.setValuesForName(["ageRange", "gender"]) cannot be set directly on query, but operation can select keys.
        
        var breakdowns = AudienceBreakdown()
        
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = ["ageRange", "gender"]
            
            operation.recordMatchedBlock = { recordId, result in
                switch result {
                case .success(let record):
                    if let age = record["ageRange"] as? String {
                        breakdowns.ageDistribution[age, default: 0] += 1
                    }
                    if let gender = record["gender"] as? String {
                        breakdowns.genderDistribution[gender, default: 0] += 1
                    }
                    breakdowns.totalUsers += 1
                case .failure(let error):
                    print("Error fetching record: \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: breakdowns)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            publicDatabase.add(operation)
        }
    }
}

/// Helper struct for analytics
struct AudienceBreakdown {
    var totalUsers: Int = 0
    var ageDistribution: [String: Int] = [:]
    var genderDistribution: [String: Int] = [:]
}
