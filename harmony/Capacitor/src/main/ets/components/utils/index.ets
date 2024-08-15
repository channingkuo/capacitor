export function toPascalCase(val: string): string {
  return val.toLowerCase()
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join('');
}

export function convertCamelToKebab(val: string): string {
  return val.replace(/([A-Z])/g, '-$1').toLowerCase().slice(1);
}