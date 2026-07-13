package com.hatggo.server;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class ChecklistGroup {
    private Long id;
    private String title;
    
    @JsonProperty("invite_code")
    private String inviteCode;
    
    private String type; // "DAILY_ROUTINE" or "DEADLINE_BOUND"
    
    @JsonProperty("start_date")
    private String startDate; // ISO 8601 string
    
    @JsonProperty("end_date")
    private String endDate; // ISO 8601 string
    
    @JsonProperty("owner_token")
    private String ownerToken;
    
    private Map<String, String> memberPermissions = new java.util.concurrent.ConcurrentHashMap<>(); // memberId -> "READ_WRITE" or "READ_ONLY"
    private Set<String> kickedMembers = java.util.Collections.newSetFromMap(new java.util.concurrent.ConcurrentHashMap<String, Boolean>()); // memberId set
    private Map<String, String> memberNicknames = new java.util.concurrent.ConcurrentHashMap<>(); // memberId -> nickname
    private List<ChecklistItem> items = new ArrayList<>();

    public ChecklistGroup() {}

    public ChecklistGroup(Long id, String title, String inviteCode, String type, String startDate, String endDate) {
        this.id = id;
        this.title = title;
        this.inviteCode = inviteCode;
        this.type = type != null ? type : "DAILY_ROUTINE";
        this.startDate = startDate;
        this.endDate = endDate;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getInviteCode() {
        return inviteCode;
    }

    public void setInviteCode(String inviteCode) {
        this.inviteCode = inviteCode;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getStartDate() {
        return startDate;
    }

    public void setStartDate(String startDate) {
        this.startDate = startDate;
    }

    public String getEndDate() {
        return endDate;
    }

    public void setEndDate(String endDate) {
        this.endDate = endDate;
    }

    public List<ChecklistItem> getItems() {
        return items;
    }

    public void setItems(List<ChecklistItem> items) {
        this.items = items;
    }

    public String getOwnerToken() {
        return ownerToken;
    }

    public void setOwnerToken(String ownerToken) {
        this.ownerToken = ownerToken;
    }

    public Map<String, String> getMemberPermissions() {
        return memberPermissions;
    }

    public void setMemberPermissions(Map<String, String> memberPermissions) {
        this.memberPermissions = memberPermissions;
    }

    public Set<String> getKickedMembers() {
        return kickedMembers;
    }

    public void setKickedMembers(Set<String> kickedMembers) {
        this.kickedMembers = kickedMembers;
    }

    public Map<String, String> getMemberNicknames() {
        return memberNicknames;
    }

    public void setMemberNicknames(Map<String, String> memberNicknames) {
        this.memberNicknames = memberNicknames;
    }
}
