import { createBrowserRouter } from 'react-router-dom';
import { Layout } from '../components/layout/Layout';
import { HomePage } from '../pages/HomePage';

export const routes = createBrowserRouter([
  {
    path: '/',
    element: <Layout />,
    children: [{ index: true, element: <HomePage /> }],
  },
]);
