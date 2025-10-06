import { useState, useEffect } from "react";
import DashboardLayout from "@/components/DashboardLayout";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";
import { useAuth } from "@/hooks/useAuth";
import { BookOpen, MessageSquare, Award } from "lucide-react";

interface Class {
  id: string;
  name: string;
  description: string;
  profiles: {
    name: string;
  };
}

interface Grade {
  id: string;
  grade: string;
  remarks: string;
  created_at: string;
  classes: {
    name: string;
  };
}

interface Announcement {
  id: string;
  title: string;
  content: string;
  created_at: string;
  profiles: {
    name: string;
  };
}

const StudentDashboard = () => {
  const [classes, setClasses] = useState<Class[]>([]);
  const [grades, setGrades] = useState<Grade[]>([]);
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const { user } = useAuth();
  const { toast } = useToast();

  useEffect(() => {
    if (user) {
      fetchEnrolledClasses();
      fetchGrades();
      fetchAnnouncements();
    }
  }, [user]);

  const fetchEnrolledClasses = async () => {
    try {
      const { data, error } = await (supabase as any)
        .from("class_students")
        .select(`
          class_id,
          classes (
            id,
            name,
            description,
            profiles:teacher_id (
              name
            )
          )
        `)
        .eq("student_id", user?.id);

      if (error) throw error;
      
      const enrolledClasses = data?.map((item: any) => item.classes) || [];
      setClasses(enrolledClasses);
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    }
  };

  const fetchGrades = async () => {
    try {
      const { data, error } = await (supabase as any)
        .from("grades")
        .select(`
          *,
          classes (
            name
          )
        `)
        .eq("student_id", user?.id)
        .order("created_at", { ascending: false });

      if (error) throw error;
      setGrades(data || []);
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    }
  };

  const fetchAnnouncements = async () => {
    try {
      const { data, error } = await (supabase as any)
        .from("announcements")
        .select(`
          *,
          profiles:teacher_id (
            name
          )
        `)
        .order("created_at", { ascending: false })
        .limit(10);

      if (error) throw error;
      setAnnouncements(data || []);
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    }
  };

  const getGradeBadgeColor = (grade: string) => {
    const firstChar = grade.charAt(0).toUpperCase();
    if (firstChar === "A") return "bg-secondary text-secondary-foreground";
    if (firstChar === "B") return "bg-primary text-primary-foreground";
    if (firstChar === "C") return "bg-accent text-accent-foreground";
    return "bg-muted text-muted-foreground";
  };

  return (
    <DashboardLayout title="Student Dashboard">
      <div className="space-y-6">
        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Enrolled Classes</CardTitle>
              <BookOpen className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{classes.length}</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Total Grades</CardTitle>
              <Award className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{grades.length}</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Announcements</CardTitle>
              <MessageSquare className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{announcements.length}</div>
            </CardContent>
          </Card>
        </div>

        {/* Main Content */}
        <Tabs defaultValue="classes" className="space-y-4">
          <TabsList>
            <TabsTrigger value="classes">My Classes</TabsTrigger>
            <TabsTrigger value="grades">Grades</TabsTrigger>
            <TabsTrigger value="announcements">Announcements</TabsTrigger>
          </TabsList>

          <TabsContent value="classes" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>Enrolled Classes</CardTitle>
                <CardDescription>Your current class schedule</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {classes.map((classItem) => (
                    <Card key={classItem.id}>
                      <CardHeader>
                        <CardTitle className="text-lg">{classItem.name}</CardTitle>
                        <CardDescription>
                          Teacher: {classItem.profiles?.name || "N/A"}
                        </CardDescription>
                      </CardHeader>
                      <CardContent>
                        <p className="text-sm text-muted-foreground">{classItem.description}</p>
                      </CardContent>
                    </Card>
                  ))}
                  {classes.length === 0 && (
                    <p className="text-center text-muted-foreground py-8">
                      You are not enrolled in any classes yet.
                    </p>
                  )}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="grades" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>My Grades</CardTitle>
                <CardDescription>View your academic performance</CardDescription>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Class</TableHead>
                      <TableHead>Grade</TableHead>
                      <TableHead>Remarks</TableHead>
                      <TableHead>Date</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {grades.map((grade) => (
                      <TableRow key={grade.id}>
                        <TableCell className="font-medium">{grade.classes.name}</TableCell>
                        <TableCell>
                          <Badge className={getGradeBadgeColor(grade.grade)}>
                            {grade.grade}
                          </Badge>
                        </TableCell>
                        <TableCell>{grade.remarks || "—"}</TableCell>
                        <TableCell>
                          {new Date(grade.created_at).toLocaleDateString()}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
                {grades.length === 0 && (
                  <p className="text-center text-muted-foreground py-8">
                    No grades posted yet.
                  </p>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="announcements" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>Recent Announcements</CardTitle>
                <CardDescription>Stay updated with class announcements</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {announcements.map((announcement) => (
                    <Card key={announcement.id}>
                      <CardHeader>
                        <CardTitle className="text-lg">{announcement.title}</CardTitle>
                        <CardDescription>
                          By {announcement.profiles?.name} • {new Date(announcement.created_at).toLocaleDateString()}
                        </CardDescription>
                      </CardHeader>
                      <CardContent>
                        <p className="text-sm">{announcement.content}</p>
                      </CardContent>
                    </Card>
                  ))}
                  {announcements.length === 0 && (
                    <p className="text-center text-muted-foreground py-8">
                      No announcements yet.
                    </p>
                  )}
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </DashboardLayout>
  );
};

export default StudentDashboard;
