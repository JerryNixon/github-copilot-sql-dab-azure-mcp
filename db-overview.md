# Database Schema Overview

## Flower Shop Plant Inventory

This database tracks plant inventory for a flower shop.

## Entity Relationship Diagram

```mermaid
erDiagram
    Categories {
        int CategoryId PK
        nvarchar Name
    }
    Plants {
        int PlantId PK
        nvarchar Name
        int CategoryId FK
        int Quantity
        decimal Price
    }
    Categories ||--o{ Plants : contains
```

## Tables

### Categories
- **CategoryId** (Primary Key): Unique identifier for each category
- **Name**: Name of the category (e.g., Succulents, Tropical Plants)

### Plants
- **PlantId** (Primary Key): Unique identifier for each plant
- **Name**: Name of the plant
- **CategoryId** (Foreign Key): Links to Categories table
- **Quantity**: Number of units in stock
- **Price**: Price per unit
