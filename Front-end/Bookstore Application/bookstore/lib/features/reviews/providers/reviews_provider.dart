import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../../../core/services/api_client.dart';
import '../models/review.dart';

class ReviewsProvider extends ChangeNotifier {
  final Map<String, List<Review>> _bookReviews = {};
  List<Review> _reviews = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Review> get reviews => _reviews;

  // Get reviews for a specific book
  List<Review> getBookReviews(String bookId) {
    return _bookReviews[bookId] ?? [];
  }

  // Add a review
  Future<void> addReview(
    int bookId,
    int? rating,
    String? comment,
    String? token,
  ) async {
    _setLoading(true);

    try {
      if (token == null) {
        _setError('Authentication required');
        _setLoading(false);
        return;
      }

      final body = <String, dynamic>{'book_id': bookId};
      if (rating != null) {
        body['rating'] = rating;
      }
      if (comment != null && comment.isNotEmpty) {
        body['comment'] = comment;
      }

      final response = await ApiClient.post(
        '/library/book-reviews/create/',
        token: token,
        body: body,
      );

      if (response.statusCode == 201) {
        // Reload reviews to get the new review
        await loadReviews(bookId, token);
      } else {
        // Parse error message from response
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['message'] ??
            errorData['errors'] ??
            'Failed to add review';
        _setError(errorMessage);
        _setLoading(false);
        throw Exception(errorMessage);
      }
    } catch (e) {
      _setError('Failed to add review: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Update a review
  Future<void> updateReview(
    int reviewId,
    int? rating,
    String? comment,
    String? token,
  ) async {
    _setLoading(true);

    try {
      if (token == null) {
        _setError('Authentication required');
        _setLoading(false);
        return;
      }

      final body = <String, dynamic>{};
      if (rating != null) {
        body['rating'] = rating;
      }
      if (comment != null && comment.isNotEmpty) {
        body['comment'] = comment;
      }

      final response = await ApiClient.put(
        '/library/book-reviews/$reviewId/update/',
        token: token,
        body: body,
      );

      if (response.statusCode == 200) {
        // Reload reviews to get the updated review
        final bookId = _reviews.firstWhere((r) => r.id == reviewId).bookId;
        await loadReviews(bookId, token);
      } else {
        _setError('Failed to update review');
        _setLoading(false);
      }
    } catch (e) {
      _setError('Failed to update review: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Delete a review
  Future<void> deleteReview(int reviewId, String? token) async {
    _setLoading(true);

    try {
      if (token == null) {
        _setError('Authentication required');
        _setLoading(false);
        return;
      }

      final response = await ApiClient.delete(
        '/library/book-reviews/$reviewId/delete/',
        token: token,
      );

      if (response.statusCode == 204) {
        // Reload reviews to get the updated list
        final bookId = _reviews.firstWhere((r) => r.id == reviewId).bookId;
        await loadReviews(bookId, token);
      } else {
        _setError('Failed to delete review');
        _setLoading(false);
      }
    } catch (e) {
      _setError('Failed to delete review: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Load reviews for a book
  Future<void> loadReviews(int bookId, String? token) async {
    _setLoading(true);
    _clearError();

    try {
      if (token == null) {
        _setError('Authentication required');
        _setLoading(false);
        return;
      }

      final response = await ApiClient.get(
        '/library/books/$bookId/reviews/',
        token: token,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final reviewsData = data['data']['evaluations'] as List;
        final reviews = reviewsData
            .map((reviewData) => Review.fromJson(reviewData))
            .toList();

        final bookIdStr = bookId.toString();
        _bookReviews[bookIdStr] = reviews;
        _reviews = reviews;
        _setLoading(false);
      } else {
        _setError('Failed to load reviews');
        _setLoading(false);
      }
    } catch (e) {
      _setError('Failed to load reviews: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Like a review
  Future<void> likeReview(int reviewId, String? token) async {
    try {
      if (token == null) {
        _setError('Authentication required');
        return;
      }

      final response = await ApiClient.post(
        '/library/book-reviews/$reviewId/like/',
        token: token,
      );

      if (response.statusCode == 200) {
        // Reload reviews to get updated like status
        final bookId = _reviews.firstWhere((r) => r.id == reviewId).bookId;
        await loadReviews(bookId, token);
      } else {
        _setError('Failed to like review');
      }
    } catch (e) {
      _setError('Failed to like review: ${e.toString()}');
    }
  }

  // Add a reply to a review
  Future<void> addReply(int reviewId, String content, String? token) async {
    _setLoading(true);

    try {
      if (token == null) {
        _setError('Authentication required');
        _setLoading(false);
        return;
      }

      final response = await ApiClient.post(
        '/library/book-reviews/replies/create/',
        token: token,
        body: {'review': reviewId, 'content': content},
      );

      if (response.statusCode == 201) {
        // Reload reviews to get the new reply
        final bookId = _reviews.firstWhere((r) => r.id == reviewId).bookId;
        await loadReviews(bookId, token);
      } else {
        _setError('Failed to add reply');
        _setLoading(false);
      }
    } catch (e) {
      _setError('Failed to add reply: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Like a reply
  Future<void> likeReply(int replyId, String? token) async {
    try {
      if (token == null) {
        _setError('Authentication required');
        return;
      }

      final response = await ApiClient.post(
        '/library/book-reviews/replies/$replyId/like/',
        token: token,
      );

      if (response.statusCode == 200) {
        // Reload reviews to get updated like status
        // We need to find which review this reply belongs to
        for (final review in _reviews) {
          if (review.replies != null) {
            for (final reply in review.replies!) {
              if (reply.id == replyId) {
                await loadReviews(review.bookId, token);
                return;
              }
            }
          }
        }
      } else {
        _setError('Failed to like reply');
      }
    } catch (e) {
      _setError('Failed to like reply: ${e.toString()}');
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
