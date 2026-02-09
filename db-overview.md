# Flower Shop Inventory — Database Overview

```mermaid
erDiagram
    Shops {
        int ShopId PK
        nvarchar Name
        nvarchar Location
    }
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
        int ShopId FK
    }
    Categories ||--o{ Plants : contains
    Shops ||--o{ Plants : stocks
```
