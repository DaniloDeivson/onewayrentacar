import React from 'react';
import { Car } from 'lucide-react';

export const Footer: React.FC = () => {
  const currentYear = new Date().getFullYear();
  
  return (
    <footer className="bg-secondary-900 text-secondary-400 py-4 px-6 w-full">
      <div className="max-w-full mx-auto">
        <div className="flex flex-col md:flex-row justify-between items-center">
          <div className="flex items-center mb-3 md:mb-0">
            <Car className="h-5 w-5 text-primary-400 mr-2" />
            <span className="text-white font-semibold">OneWay Rent A Car</span>
          </div>
          <div className="text-sm">
            &copy; {currentYear} OneWay Rent A Car. Todos os direitos reservados.
          </div>
        </div>
      </div>
    </footer>
  );
};