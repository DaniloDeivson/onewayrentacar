export function getEmployeeNameById(employeeId: string, employees: { id: string, name: string }[]): string {
  const found = employees.find(e => e.id === employeeId);
  return found ? found.name : '';
} 