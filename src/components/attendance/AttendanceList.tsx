import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Calendar, Clock, Users } from "lucide-react";
import { format } from "date-fns";

interface AttendanceListProps {
  classId: string;
  studentView?: boolean;
}

export function AttendanceList({ classId, studentView = false }: AttendanceListProps) {
  const { data: attendance, isLoading } = useQuery({
    queryKey: ["attendance", classId, studentView],
    queryFn: async () => {
      let query = (supabase as any)
        .from("attendance")
        .select(`
          *
        `)
        .eq("class_id", classId)
        .order("date", { ascending: false });

      if (studentView) {
        const { data: { user } } = await supabase.auth.getUser();
        query = query.eq("student_id", user?.id);
      }

      const { data: attendanceData, error } = await query;
      if (error) throw error;

      // Fetch student profiles separately
      if (!studentView && attendanceData) {
        const studentIds = [...new Set(attendanceData.map((a: any) => a.student_id))] as string[];
        const { data: profiles } = await supabase
          .from("profiles")
          .select("id, name, email")
          .in("id", studentIds);

        const profileMap = new Map(profiles?.map(p => [p.id, p]) || []);
        return attendanceData.map((a: any) => ({
          ...a,
          student_profile: profileMap.get(a.student_id),
        }));
      }

      return attendanceData;
    },
  });

  if (isLoading) return <div>Loading attendance...</div>;

  const getStatusColor = (status: string) => {
    switch (status) {
      case "present":
        return "bg-green-500";
      case "absent":
        return "bg-red-500";
      case "late":
        return "bg-yellow-500";
      case "excused":
        return "bg-blue-500";
      default:
        return "bg-gray-500";
    }
  };

  return (
    <div className="space-y-4">
      {attendance?.map((record) => (
        <Card key={record.id}>
          <CardContent className="pt-6">
            <div className="flex items-center justify-between">
              <div className="space-y-2">
                {!studentView && record.student_profile && (
                  <div className="flex items-center gap-2">
                    <Users className="h-4 w-4 text-muted-foreground" />
                    <span className="font-medium">{record.student_profile.name}</span>
                  </div>
                )}
                <div className="flex items-center gap-4 text-sm text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <Calendar className="h-4 w-4" />
                    {format(new Date(record.date), "MMM dd, yyyy")}
                  </div>
                  <div className="flex items-center gap-1">
                    <Clock className="h-4 w-4" />
                    {format(new Date(record.time_in), "hh:mm a")}
                  </div>
                </div>
                {record.remarks && (
                  <p className="text-sm text-muted-foreground">{record.remarks}</p>
                )}
              </div>
              <div className="flex items-center gap-2">
                <Badge className={getStatusColor(record.status)}>
                  {record.status}
                </Badge>
                {record.method && (
                  <Badge variant="outline">{record.method}</Badge>
                )}
              </div>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
