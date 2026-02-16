package com.demo.svcd.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    @GetMapping
    public List<Map<String, Object>> getNotifications() {
        return List.of(
                Map.of("id", 1, "type", "EMAIL", "message", "Order confirmed", "read", true),
                Map.of("id", 2, "type", "SMS", "message", "Order shipped", "read", false)
        );
    }
}
