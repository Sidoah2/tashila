import math
from typing import Any


def paginate(page: int, limit: int) -> dict[str, int]:
    page = max(1, page)
    limit = max(1, min(limit, 100))
    return {
        "skip": (page - 1) * limit,
        "limit": limit,
        "page": page,
    }


def paginated_response(
    items: list[Any],
    total: int,
    page: int,
    limit: int,
) -> dict[str, Any]:
    pages = math.ceil(total / limit) if limit > 0 and total > 0 else 0
    if total == 0:
        pages = 0
    return {
        "items": items,
        "total": total,
        "page": page,
        "limit": limit,
        "pages": pages,
    }
