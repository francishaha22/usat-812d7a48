import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ClipboardList, Calendar, Award } from "lucide-react";
import { format } from "date-fns";

interface AssessmentsListProps {
  classId: string;
  studentView?: boolean;
}

export function AssessmentsList({ classId, studentView = false }: AssessmentsListProps) {
  const { data: assessments, isLoading } = useQuery({
    queryKey: ["assessments", classId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("assessments")
        .select(`
          *,
          ${studentView ? `
            assessment_submissions!inner (
              score,
              submitted_at,
              feedback
            )
          ` : ""}
        `)
        .eq("class_id", classId)
        .order("created_at", { ascending: false });

      if (error) throw error;
      return data;
    },
  });

  if (isLoading) return <div>Loading assessments...</div>;

  const getTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      quiz: "bg-blue-500",
      exam: "bg-red-500",
      assignment: "bg-green-500",
      performance_task: "bg-purple-500",
    };
    return colors[type] || "bg-gray-500";
  };

  return (
    <div className="grid gap-4 md:grid-cols-2">
      {assessments?.map((assessment: any) => (
        <Card key={assessment.id}>
          <CardHeader>
            <div className="flex items-start justify-between">
              <ClipboardList className="h-8 w-8 text-muted-foreground" />
              <Badge className={getTypeColor(assessment.type)}>
                {assessment.type.replace("_", " ")}
              </Badge>
            </div>
            <CardTitle>{assessment.title}</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground mb-4">
              {assessment.description}
            </p>
            <div className="space-y-2 text-sm">
              <div className="flex items-center gap-2">
                <Award className="h-4 w-4" />
                <span>Total Points: {assessment.total_points}</span>
              </div>
              {assessment.deadline && (
                <div className="flex items-center gap-2">
                  <Calendar className="h-4 w-4" />
                  <span>Due: {format(new Date(assessment.deadline), "MMM dd, yyyy hh:mm a")}</span>
                </div>
              )}
              {studentView && assessment.assessment_submissions?.[0] && (
                <div className="mt-4 p-3 bg-secondary rounded-lg">
                  <div className="font-semibold">Your Score</div>
                  <div className="text-2xl font-bold">
                    {assessment.assessment_submissions[0].score} / {assessment.total_points}
                  </div>
                  {assessment.assessment_submissions[0].feedback && (
                    <div className="mt-2 text-xs text-muted-foreground">
                      {assessment.assessment_submissions[0].feedback}
                    </div>
                  )}
                </div>
              )}
            </div>
            {!studentView ? (
              <Button className="w-full mt-4">View Submissions</Button>
            ) : (
              <Button className="w-full mt-4">
                {assessment.assessment_submissions?.[0] ? "View Details" : "Submit"}
              </Button>
            )}
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
