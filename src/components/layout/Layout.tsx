import { Outlet } from 'react-router-dom';
import { BottomNav } from './BottomNav';
import { TopBar } from './TopBar';

export const Layout = () => (
  <div className="app-shell">
    <TopBar />
    <main className="page">
      <Outlet />
    </main>
    <BottomNav />
  </div>
);
