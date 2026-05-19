import { Routes } from '@angular/router';
import { DashboardLayoutComponent } from './layouts/dashboard-layout/dashboard-layout.component';

export const dashboardRoutes: Routes = [
  {
    path: '',
    component: DashboardLayoutComponent,
    children: [
      {
        path: 'inicio',
        loadComponent: () => import('./pages/inicio-page/inicio-page.component').then(m => m.InicioPageComponent),
      },
      {
        path: 'resumen',
        loadComponent: () => import('./pages/resumen-page/resumen-page.component').then(m => m.ResumenPageComponent),
      },
      {
        path: 'perfil',
        loadComponent: () => import('./pages/user-page/user-page.component').then(m => m.UserPageComponent),
      }
    ],
  },
  {
    path: '**',
    redirectTo: 'inicio',
  },
];

export default dashboardRoutes;
