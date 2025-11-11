import 'dart:async';
import 'dart:math';

import '../../models/job.dart';
import '../services/services_repository.dart';

class JobsRepository {
  JobsRepository();

  static const String _currentClientId = 'client-demo';
  static const String _currentFreelancerId = 'freelancer-andi';

  final List<Job> _jobs = <Job>[
    Job(
      id: 'job-001',
      clientId: 'client-demo',
      freelancerId: 'freelancer-andi',
      serviceId: 'design-001',
      serviceTitle: 'Logo Design Premium',
      amount: 350.0,
      status: JobStatus.pending,
    ),
    Job(
      id: 'job-002',
      clientId: 'client-demo',
      freelancerId: 'freelancer-andi',
      serviceId: 'writing-002',
      serviceTitle: 'Penulisan Artikel SEO',
      amount: 220.0,
      status: JobStatus.inProgress,
    ),
    Job(
      id: 'job-003',
      clientId: 'client-demo',
      freelancerId: 'freelancer-andi',
      serviceId: 'dev-003',
      serviceTitle: 'Landing Page Responsif',
      amount: 780.0,
      status: JobStatus.completed,
    ),
  ];

  Future<Job> createOrder(String serviceId, double amount) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final service = await servicesRepository.getServiceById(serviceId);
    final id = 'job-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}';
    final job = Job(
      id: id,
      clientId: _currentClientId,
      freelancerId: _currentFreelancerId,
      serviceId: serviceId,
      serviceTitle: service?.title ?? 'Servis $serviceId',
      amount: amount,
      status: JobStatus.pending,
    );

    _jobs.insert(0, job);
    return job;
  }

  Future<bool> acceptJob(String jobId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _jobs.indexWhere((Job job) => job.id == jobId);
    if (index == -1) {
      return false;
    }

    final job = _jobs[index];
    if (job.status != JobStatus.pending) {
      return false;
    }

    _jobs[index] = job.copyWith(status: JobStatus.inProgress);
    return true;
  }

  Future<bool> rejectJob(String jobId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _jobs.indexWhere((Job job) => job.id == jobId);
    if (index == -1) {
      return false;
    }

    final job = _jobs[index];
    if (job.status != JobStatus.pending) {
      return false;
    }

    _jobs[index] = job.copyWith(status: JobStatus.rejected);
    return true;
  }

  Future<bool> markCompleted(String jobId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _jobs.indexWhere((Job job) => job.id == jobId);
    if (index == -1) {
      return false;
    }

    final job = _jobs[index];
    if (job.status != JobStatus.inProgress) {
      return false;
    }

    _jobs[index] = job.copyWith(status: JobStatus.completed);
    return true;
  }

  List<Job> getClientJobs() {
    return List<Job>.unmodifiable(
      _jobs
          .where((Job job) => job.clientId == _currentClientId)
          .toList(growable: false),
    );
  }

  List<Job> getFreelancerJobs() {
    return List<Job>.unmodifiable(
      _jobs
          .where((Job job) => job.freelancerId == _currentFreelancerId)
          .toList(growable: false),
    );
  }
}

final jobsRepository = JobsRepository();
