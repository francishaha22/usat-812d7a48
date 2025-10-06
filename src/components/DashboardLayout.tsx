import { ReactNode } from "react";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { LogOut, GraduationCap } from "lucide-react";
import { NotificationCenter } from "./notifications/NotificationCenter";

interface DashboardLayoutProps {
  children: ReactNode;
  title: string;
}

const DashboardLayout = ({ children, title }: DashboardLayoutProps) => {
  const { user, role, signOut } = useAuth();

  const getRoleBadgeColor = () => {
    switch (role) {
      case "admin":
        return "bg-[hsl(var(--admin-badge))] text-white hover:bg-[hsl(var(--admin-badge))]/90";
      case "teacher":
        return "bg-[hsl(var(--teacher-badge))] text-white hover:bg-[hsl(var(--teacher-badge))]/90";
      case "student":
        return "bg-[hsl(var(--student-badge))] text-white hover:bg-[hsl(var(--student-badge))]/90";
      default:
        return "";
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card shadow-sm sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-primary rounded-lg flex items-center justify-center">
              <GraduationCap className="w-6 h-6 text-primary-foreground" />
            </div>
            <div>
              <h1 className="text-xl font-bold">{title}</h1>
              <p className="text-sm text-muted-foreground">{user?.email}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <NotificationCenter />
            <Badge className={getRoleBadgeColor()}>
              {role?.toUpperCase()}
            </Badge>
            <Button variant="outline" size="sm" onClick={signOut}>
              <LogOut className="w-4 h-4 mr-2" />
              Sign Out
            </Button>
          </div>
        </div>
      </header>
      <main className="container mx-auto px-4 py-8">
        {children}
      </main>
    </div>
  );
};

export default DashboardLayout;
