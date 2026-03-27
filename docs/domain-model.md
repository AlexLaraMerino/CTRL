# CTRL — Domain Model

## Core Idea
Each date has its own operational state.

## Entities

### Employee
- id
- name
- active

### WorkSite
- id
- name
- city
- lat
- lng

### DailyState
- date
- notes
- visibleWorkSiteIds
- employeePlacements
- absentEmployeeIds

### EmployeePlacement
- employeeId
- lat
- lng
- workSiteId

## Rules
- Days are independent
- Copy is explicit
- Notes are per day
- The map is a view over the daily state, not the source of truth itself

## Future Extension
For documents by worksite, the future direction is:
- worksite folders
- PDFs per worksite
- annotations stored separately where possible
