export function resolveMenuItemId(item, index = 0) {
  if (item?.itemId && String(item.itemId).trim()) {
    return String(item.itemId).trim();
  }

  if (item?._id) {
    return item._id.toString();
  }

  const slug = String(item?.name || `menu-item-${index + 1}`)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

  return `legacy-${index + 1}-${slug || 'item'}`;
}

export function findRestaurantMenuItem(restaurant, menuItemId) {
  for (const [index, item] of (restaurant.menuItems || []).entries()) {
    const resolvedId = resolveMenuItemId(item, index);
    if (resolvedId === String(menuItemId)) {
      return { item, index, id: resolvedId };
    }
  }

  return null;
}
