# CTRL — Architecture

## 1. Purpose
CTRL is now an iPad-first operational planning application for daily field coordination.

## 2. Core Principle
The map is the core of the product. Each date has its own persistent operational snapshot.

## 3. Product Direction
- Primary platform: iPad
- UX priority: fluid touch interaction
- Native Apple frameworks are preferred where they materially improve quality

## 4. Current Technical Direction
- SwiftUI
- MapKit
- Native iOS app lifecycle
- Local-first persistence

## 5. Initial Persistence
- Codable domain models
- File-based local persistence
- Backend later, after validating the iPad workflow

## 6. Core Idea
Each date has an independent operational state:
- notes
- visible worksites
- employee placements

## 7. Priorities
1. iPad layout
2. Daily state model
3. Persistent local snapshots by date
4. Fluid map interaction
5. Copy day / copy yesterday / apply week
6. Worksite documents
7. Backend and sync

## 8. Future Document Strategy
Documents belong to each worksite.
For plans and PDFs, the intended native direction is:
- PDFKit for viewing
- PencilKit for annotation
- original file preserved
- annotations stored separately when possible

## 9. Non Goals
- ERP
- complex permissions
- time slots
- business-heavy planning logic

## 10. Philosophy
Fast, tactile, visual, reliable.
