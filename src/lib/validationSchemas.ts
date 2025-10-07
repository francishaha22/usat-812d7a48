import { z } from "zod";

// Assessment Types
export const assessmentTypes = ["quiz", "exam", "assignment", "performance_task"] as const;
export type AssessmentType = typeof assessmentTypes[number];

export const assessmentSchema = z.object({
  title: z.string().trim().min(1, "Title is required").max(200, "Title must be less than 200 characters"),
  description: z.string().trim().max(1000, "Description must be less than 1000 characters").optional(),
  type: z.enum(assessmentTypes, { 
    errorMap: () => ({ message: "Invalid assessment type" })
  }),
  total_points: z.number().positive("Total points must be positive").max(1000, "Total points must be less than 1000"),
  weight: z.number().positive("Weight must be positive").max(100, "Weight must be less than 100").optional(),
  deadline: z.string().optional(),
  class_id: z.string().uuid("Invalid class ID"),
});

// Attendance Status
export const attendanceStatuses = ["present", "absent", "late", "excused"] as const;
export type AttendanceStatus = typeof attendanceStatuses[number];

// Attendance Method
export const attendanceMethods = ["manual", "qr_code"] as const;
export type AttendanceMethod = typeof attendanceMethods[number];

export const attendanceSchema = z.object({
  student_id: z.string().uuid("Invalid student ID"),
  class_id: z.string().uuid("Invalid class ID"),
  status: z.enum(attendanceStatuses, {
    errorMap: () => ({ message: "Invalid attendance status" })
  }),
  method: z.enum(attendanceMethods, {
    errorMap: () => ({ message: "Invalid attendance method" })
  }).optional(),
  date: z.string().optional(),
  time_in: z.string().optional(),
  remarks: z.string().trim().max(500, "Remarks must be less than 500 characters").optional(),
});

// Chat Room Types
export const chatRoomTypes = ["class", "direct", "group"] as const;
export type ChatRoomType = typeof chatRoomTypes[number];

export const chatRoomSchema = z.object({
  name: z.string().trim().min(1, "Name is required").max(100, "Name must be less than 100 characters"),
  type: z.enum(chatRoomTypes, {
    errorMap: () => ({ message: "Invalid chat room type" })
  }),
  class_id: z.string().uuid("Invalid class ID").optional(),
});

// Message Schema
export const messageSchema = z.object({
  content: z.string().trim().min(1, "Message cannot be empty").max(10000, "Message must be less than 10000 characters"),
  room_id: z.string().uuid("Invalid room ID"),
});

// Notification Types
export const notificationTypes = ["announcement", "grade", "assignment", "attendance", "general"] as const;
export type NotificationType = typeof notificationTypes[number];

export const notificationSchema = z.object({
  title: z.string().trim().min(1, "Title is required").max(200, "Title must be less than 200 characters"),
  message: z.string().trim().min(1, "Message is required").max(1000, "Message must be less than 1000 characters"),
  type: z.enum(notificationTypes, {
    errorMap: () => ({ message: "Invalid notification type" })
  }),
  link: z.string().trim().max(500, "Link must be less than 500 characters").optional(),
  user_id: z.string().uuid("Invalid user ID"),
});

// Announcement Schema
export const announcementSchema = z.object({
  title: z.string().trim().min(1, "Title is required").max(200, "Title must be less than 200 characters"),
  content: z.string().trim().min(1, "Content is required").max(50000, "Content must be less than 50000 characters"),
  class_id: z.string().uuid("Invalid class ID").optional(),
});

// Assessment Submission Schema
export const assessmentSubmissionSchema = z.object({
  assessment_id: z.string().uuid("Invalid assessment ID"),
  score: z.number().min(0, "Score cannot be negative").optional(),
  feedback: z.string().trim().max(5000, "Feedback must be less than 5000 characters").optional(),
});
