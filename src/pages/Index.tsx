import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { GraduationCap, BookOpen, Users, Award } from "lucide-react";

const Index = () => {
  const { user, role, loading } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!loading && user && role) {
      // Redirect to appropriate dashboard if already logged in
      switch (role) {
        case "admin":
          navigate("/admin/dashboard");
          break;
        case "teacher":
          navigate("/teacher/dashboard");
          break;
        case "student":
          navigate("/student/dashboard");
          break;
      }
    }
  }, [user, role, loading, navigate]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary/10 via-background to-secondary/10">
      <div className="container mx-auto px-4 py-16">
        <div className="text-center mb-16">
          <div className="mx-auto w-20 h-20 bg-primary rounded-2xl flex items-center justify-center mb-6">
            <GraduationCap className="w-12 h-12 text-primary-foreground" />
          </div>
          <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
            School Management System
          </h1>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto mb-8">
            A comprehensive platform for managing classes, grades, and communication between administrators, teachers, and students.
          </p>
          <Button size="lg" onClick={() => navigate("/login")} className="text-lg px-8">
            Sign In to Your Account
          </Button>
        </div>

        <div className="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto">
          <div className="bg-card p-6 rounded-lg shadow-lg border">
            <div className="w-12 h-12 bg-[hsl(var(--admin-badge))]/10 rounded-lg flex items-center justify-center mb-4">
              <Users className="w-6 h-6 text-[hsl(var(--admin-badge))]" />
            </div>
            <h3 className="text-xl font-bold mb-2">Admin Portal</h3>
            <p className="text-muted-foreground">
              Manage users, create accounts for teachers and students, and oversee all school operations.
            </p>
          </div>

          <div className="bg-card p-6 rounded-lg shadow-lg border">
            <div className="w-12 h-12 bg-[hsl(var(--teacher-badge))]/10 rounded-lg flex items-center justify-center mb-4">
              <BookOpen className="w-6 h-6 text-[hsl(var(--teacher-badge))]" />
            </div>
            <h3 className="text-xl font-bold mb-2">Teacher Portal</h3>
            <p className="text-muted-foreground">
              Manage classes, post announcements, assign grades, and communicate with students.
            </p>
          </div>

          <div className="bg-card p-6 rounded-lg shadow-lg border">
            <div className="w-12 h-12 bg-[hsl(var(--student-badge))]/10 rounded-lg flex items-center justify-center mb-4">
              <Award className="w-6 h-6 text-[hsl(var(--student-badge))]" />
            </div>
            <h3 className="text-xl font-bold mb-2">Student Portal</h3>
            <p className="text-muted-foreground">
              View enrolled classes, check grades, and stay updated with announcements.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Index;
