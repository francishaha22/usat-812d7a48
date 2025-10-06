import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { FileText, Download, Eye } from "lucide-react";
import { format } from "date-fns";

interface MaterialsListProps {
  classId: string;
}

export function MaterialsList({ classId }: MaterialsListProps) {
  const { data: materials, isLoading } = useQuery({
    queryKey: ["learning-materials", classId],
    queryFn: async () => {
      const { data: materialsData, error } = await (supabase as any)
        .from("learning_materials")
        .select("*")
        .eq("class_id", classId)
        .order("created_at", { ascending: false });

      if (error) throw error;

      // Fetch teacher profiles separately
      if (materialsData) {
        const teacherIds = [...new Set(materialsData.map((m: any) => m.teacher_id))] as string[];
        const { data: profiles } = await supabase
          .from("profiles")
          .select("id, name")
          .in("id", teacherIds);

        const profileMap = new Map(profiles?.map(p => [p.id, p]) || []);
        return materialsData.map((m: any) => ({
          ...m,
          teacher_profile: profileMap.get(m.teacher_id),
        }));
      }

      return materialsData;
    },
  });

  if (isLoading) return <div>Loading materials...</div>;

  const getFileIcon = (type: string) => {
    return <FileText className="h-8 w-8 text-muted-foreground" />;
  };

  const handleDownload = async (url: string, title: string) => {
    try {
      const { data } = await supabase.storage
        .from("learning-materials")
        .download(url);
      
      if (data) {
        const blob = new Blob([data]);
        const link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = title;
        link.click();
      }
    } catch (error) {
      console.error("Error downloading file:", error);
    }
  };

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {materials?.map((material) => (
        <Card key={material.id}>
          <CardHeader>
            <div className="flex items-start justify-between">
              {getFileIcon(material.file_type || "document")}
              <Badge variant="outline">{material.file_type}</Badge>
            </div>
            <CardTitle className="text-lg">{material.title}</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground mb-4">
              {material.description}
            </p>
            {material.topic && (
              <Badge className="mb-2">{material.topic}</Badge>
            )}
            <div className="text-xs text-muted-foreground mb-4">
              {material.teacher_profile && (
                <div>By {material.teacher_profile.name}</div>
              )}
              <div>{format(new Date(material.created_at), "MMM dd, yyyy")}</div>
              <div>Version {material.version}</div>
            </div>
            <div className="flex gap-2">
              <Button size="sm" variant="outline" className="flex-1">
                <Eye className="h-4 w-4 mr-1" />
                Preview
              </Button>
              <Button
                size="sm"
                className="flex-1"
                onClick={() => handleDownload(material.file_url || "", material.title)}
              >
                <Download className="h-4 w-4 mr-1" />
                Download
              </Button>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
