//
//  Device.swift
//  MyApp
//
//  Created by Rio on 6/16/26.
//  Version 1.1 Created 6/16/26
// Version 1.2 Beta Created 6/17/26

import Foundation
import SwiftUI

// Device Status Enum
enum DeviceStatus: String, Codable, CaseIterable, Hashable {
    case operational = "Operational"
    case diagnostic = "Diagnostic"
    case decommissioned = "Decommissioned"
    
    var color: Color {
        switch self {
        case .operational: return .green
        case .diagnostic: return .yellow
        case .decommissioned: return .red
        }
    }
}

// Universal Part Structure
struct Part: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var serialNumber: String
    var cost: Double
    var notes: String
    
    init(name: String, serialNumber: String, cost: Double, notes: String) {
        self.id = UUID()
        self.name = name
        self.serialNumber = serialNumber
        self.cost = cost
        self.notes = notes
    }
    
    enum CodingKeys: String, CodingKey { case id, name, serialNumber, cost, notes }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        serialNumber = try container.decode(String.self, forKey: .serialNumber)
        cost = try container.decode(Double.self, forKey: .cost)
        notes = try container.decode(String.self, forKey: .notes)
    }
}

// Device Structure
struct Device: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var category: String
    var manufacturer: String
    var model: String
    var serialNumber: String
    var osVersion: String
    var processor: String
    var gpu: String
    var ram: String
    var storage: String
    var year: String
    var notes: String
    var badgeColor: String
    var installedParts: [Part]
    var status: DeviceStatus // NEW: V1.2 Health Status
    
    init(id: String, category: String, manufacturer: String, model: String, serialNumber: String, osVersion: String, processor: String, gpu: String, ram: String, storage: String, year: String, notes: String, badgeColor: String = "Cyan", installedParts: [Part] = [], status: DeviceStatus = .operational) {
        self.id = id; self.category = category; self.manufacturer = manufacturer; self.model = model
        self.serialNumber = serialNumber; self.osVersion = osVersion; self.processor = processor; self.gpu = gpu
        self.ram = ram; self.storage = storage; self.year = year; self.notes = notes; self.badgeColor = badgeColor
        self.installedParts = installedParts; self.status = status
    }
    
    enum CodingKeys: String, CodingKey {
        case id, category, manufacturer, model, serialNumber, osVersion, processor, gpu, ram, storage, year, notes, badgeColor, installedParts, status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        manufacturer = try container.decode(String.self, forKey: .manufacturer)
        model = try container.decode(String.self, forKey: .model)
        serialNumber = try container.decode(String.self, forKey: .serialNumber)
        osVersion = try container.decode(String.self, forKey: .osVersion)
        processor = try container.decode(String.self, forKey: .processor)
        gpu = try container.decode(String.self, forKey: .gpu)
        ram = try container.decode(String.self, forKey: .ram)
        storage = try container.decode(String.self, forKey: .storage)
        year = try container.decode(String.self, forKey: .year)
        notes = try container.decode(String.self, forKey: .notes)
        
        badgeColor = try container.decodeIfPresent(String.self, forKey: .badgeColor) ?? "Cyan"
        installedParts = try container.decodeIfPresent([Part].self, forKey: .installedParts) ?? []
        // Safe Decoder: Upgrades older saves to 'Operational'
        status = try container.decodeIfPresent(DeviceStatus.self, forKey: .status) ?? .operational
    }
}
