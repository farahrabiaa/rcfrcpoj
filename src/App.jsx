import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { ToastContainer } from 'react-toastify';
import { AuthProvider } from './contexts/AuthContext';
import { SettingsProvider } from './contexts/SettingsContext';
import ProtectedRoute from './components/ProtectedRoute';
import Login from './components/Login';
import AdminDashboard from './components/AdminDashboard';
import NotFound from './components/NotFound';
import 'react-toastify/dist/ReactToastify.css';
import './index.css';

// This component handles redirecting to the appropriate dashboard based on user role
function RoleBasedRedirect() {
  const location = useLocation();
  
  // If we're already on a specific route, don't redirect
  if (location.pathname !== '/') {
    return null;
  }
  
  return (
    <Navigate to="/login" replace />
  );
}

function App() {
  return (
    <AuthProvider>
      <SettingsProvider>
        <Router>
          <div className="w-full overflow-x-hidden">
            <Routes>
              <Route path="/login" element={<Login />} />
              
              {/* Admin Dashboard Routes */}
              <Route path="/admin-dashboard/*" element={
                <ProtectedRoute allowedRoles={['admin']}>
                  <AdminDashboard />
                </ProtectedRoute>
              } />
              
              {/* Root path - redirect based on role */}
              <Route path="/" element={<RoleBasedRedirect />} />
              
              {/* Catch all route for 404 */}
              <Route path="*" element={<NotFound />} />
            </Routes>
            
            <ToastContainer
              position="top-center"
              autoClose={3000}
              hideProgressBar={false}
              newestOnTop
              closeOnClick
              rtl
              pauseOnFocusLoss
              draggable
              pauseOnHover
              theme="light"
            />
          </div>
        </Router>
      </SettingsProvider>
    </AuthProvider>
  );
}

export default App;