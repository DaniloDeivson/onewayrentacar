import React from 'react';
import { Menu, Car } from 'lucide-react';
import { UserMenu } from './UserMenu';

interface MobileHeaderProps {
  onMenuClick: () => void;
}

export const MobileHeader: React.FC<MobileHeaderProps> = ({ onMenuClick }) => {
  return (
    <header className="bg-secondary-900 text-white px-4 py-3 flex items-center justify-between shadow-lg">
      <button
        onClick={onMenuClick}
        className="p-2 rounded-lg hover:bg-secondary-800 transition-colors"
      >
        <Menu className="h-6 w-6" />
      </button>
      
      <div className="flex items-center">
        <Car className="h-6 w-6 text-primary-400 mr-2" />
        <div>
          <h1 className="font-bold text-lg">OneWay</h1>
        </div>
      </div>

      <UserMenu />
    </header>
  );
};