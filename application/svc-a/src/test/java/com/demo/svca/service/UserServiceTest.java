package com.demo.svca.service;

import com.demo.svca.model.User;
import com.demo.svca.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private KafkaTemplate<String, String> kafkaTemplate;

    @InjectMocks
    private UserService userService;

    @Test
    void getUserById_shouldReturnUser_whenExists() {
        User user = new User("Alice", "alice@example.com");
        user.setId(1L);
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        Optional<User> result = userService.getUserById(1L);

        assertTrue(result.isPresent());
        assertEquals("Alice", result.get().getName());
        verify(userRepository).findById(1L);
    }

    @Test
    void getUserById_shouldReturnEmpty_whenNotExists() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        Optional<User> result = userService.getUserById(99L);

        assertFalse(result.isPresent());
    }

    @Test
    void createUser_shouldSaveAndPublishEvent() {
        User user = new User("Bob", "bob@example.com");
        User saved = new User("Bob", "bob@example.com");
        saved.setId(1L);
        when(userRepository.save(any(User.class))).thenReturn(saved);

        User result = userService.createUser(user);

        assertEquals(1L, result.getId());
        verify(userRepository).save(user);
        verify(kafkaTemplate).send(eq("user-events"), eq("user.created"), contains("1"));
    }

    @Test
    void deleteUser_shouldDeleteAndPublishEvent() {
        userService.deleteUser(1L);

        verify(userRepository).deleteById(1L);
        verify(kafkaTemplate).send(eq("user-events"), eq("user.deleted"), contains("1"));
    }
}
