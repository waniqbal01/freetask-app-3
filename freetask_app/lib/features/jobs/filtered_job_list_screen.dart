import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/error_utils.dart';
import '../../models/job.dart';
import 'jobs_repository.dart';
import 'widgets/job_card_skeleton.dart';
import 'widgets/job_status_badge.dart';
import '../../core/constants/app_formatters.dart';

class FilteredJobListScreen extends StatefulWidget {
  const FilteredJobListScreen({
    super.key,
    required this.title,
    required this.role,
    required this.statuses,
  });

  final String title;
  final String role; // 'client' or 'freelancer'
  final List<String> statuses;

  @override
  State<FilteredJobListScreen> createState() => _FilteredJobListScreenState();
}

class _FilteredJobListScreenState extends State<FilteredJobListScreen> {
  final List<Job> _jobs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Job> jobs;
      if (widget.role == 'client') {
        jobs = await jobsRepository.getClientJobs(status: widget.statuses);
      } else {
        jobs = await jobsRepository.getFreelancerJobs(status: widget.statuses);
      }

      if (!mounted) return;
      setState(() {
        _jobs.clear();
        _jobs.addAll(jobs);
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = resolveDioErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat senarai job.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openJobDetail(Job job) {
    context.push(
      '/jobs/${job.id}',
      extra: <String, dynamic>{
        'job': job,
        // If viewing as client (role='client'), passes true
        'isClientView': widget.role == 'client',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, __) => const JobCardSkeleton(),
            )
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _jobs.isEmpty
                  ? const Center(child: Text('Tiada job ditemui.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final job = _jobs[index];
                        final statusVisual = mapJobStatusVisual(job.status);

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openJobDetail(job),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          job.serviceTitle,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      JobStatusBadge(visual: statusVisual),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'RM ${AppFormatters.formatAmount(job.amount)}'),
                                  const SizedBox(height: 4),
                                  Text(AppFormatters.formatDateTime(
                                      job.createdAt)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
