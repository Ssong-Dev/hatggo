package com.hatggo.server;

import com.fasterxml.jackson.annotation.JsonProperty;

public class ChecklistItem {
    private Long id;
    
    @JsonProperty("room_id")
    private Long roomId;
    
    @JsonProperty("content")
    private String title;
    
    @JsonProperty("is_completed")
    private boolean isChecked;
    
    @JsonProperty("completed_by_uuid")
    private String completedBy;
    
    @JsonProperty("completed_at")
    private String completedAt;

    public ChecklistItem() {}

    public ChecklistItem(Long id, Long roomId, String title, boolean isChecked, String completedBy, String completedAt) {
        this.id = id;
        this.roomId = roomId;
        this.title = title;
        this.isChecked = isChecked;
        this.completedBy = completedBy;
        this.completedAt = completedAt;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getRoomId() {
        return roomId;
    }

    public void setRoomId(Long roomId) {
        this.roomId = roomId;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    @JsonProperty("is_completed")
    public boolean isChecked() {
        return isChecked;
    }

    @JsonProperty("is_completed")
    public void setChecked(boolean checked) {
        isChecked = checked;
    }

    public String getCompletedBy() {
        return completedBy;
    }

    public void setCompletedBy(String completedBy) {
        this.completedBy = completedBy;
    }

    public String getCompletedAt() {
        return completedAt;
    }

    public void setCompletedAt(String completedAt) {
        this.completedAt = completedAt;
    }
}
